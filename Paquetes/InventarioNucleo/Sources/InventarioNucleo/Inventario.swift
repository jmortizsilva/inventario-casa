import Foundation
import Observation

public enum ErrorInventario: Error, Equatable, Sendable {
    case nombre(ErrorNombre)
    case noEncontrado
    case carga(String)
    case guardado(String)
}

/// Estado del inventario y todas las operaciones que lo cambian. Primero guarda
/// en el almacén y solo si sale bien actualiza lo que ve la interfaz, para que
/// pantalla y datos guardados no difieran tras un error.
@MainActor
@Observable
public final class Inventario {
    private let almacen: Almacen
    private let ahora: () -> Date
    // Incluyen lo borrado: hará falta para sincronizar.
    private var todasCategorias: [UUID: Categoria] = [:]
    private var todosProductos: [UUID: Producto] = [:]

    public init(almacen: Almacen, ahora: @escaping () -> Date = Date.init) {
        self.almacen = almacen
        self.ahora = ahora
    }

    public func cargar() throws(ErrorInventario) {
        do {
            let categorias = try almacen.cargarCategorias()
            let productos = try almacen.cargarProductos()
            todasCategorias = Dictionary(uniqueKeysWithValues: categorias.map { ($0.id, $0) })
            todosProductos = Dictionary(uniqueKeysWithValues: productos.map { ($0.id, $0) })
        } catch {
            throw .carga(String(describing: error))
        }
    }

    // MARK: Consultas

    public var categorias: [Categoria] {
        todasCategorias.values
            .filter { !$0.estaBorrada }
            .sorted { Nombres.vaAntes($0.nombre, $1.nombre) }
    }

    public func categoria(_ id: UUID) -> Categoria? {
        todasCategorias[id].flatMap { $0.estaBorrada ? nil : $0 }
    }

    public func productos(en categoriaId: UUID) -> [Producto] {
        todosProductos.values
            .filter { $0.categoriaId == categoriaId && !$0.estaBorrado }
            .sorted { Nombres.vaAntes($0.nombre, $1.nombre) }
    }

    public func producto(_ id: UUID) -> Producto? {
        todosProductos[id].flatMap { $0.estaBorrado ? nil : $0 }
    }

    public var listaCompra: [Producto] {
        ListaCompra.productos(de: Array(todosProductos.values))
    }

    // MARK: Categorías

    @discardableResult
    public func crearCategoria(nombre: String) throws(ErrorInventario) -> Categoria {
        let limpio = try validar(nombre, entre: categorias.map(\.nombre))
        let nueva = Categoria(nombre: limpio, creado: ahora())
        try guardar(categorias: [nueva])
        return nueva
    }

    @discardableResult
    public func renombrarCategoria(_ id: UUID, a nombre: String) throws(ErrorInventario) -> Categoria {
        guard var categoria = categoria(id) else { throw .noEncontrado }
        let otras = categorias.filter { $0.id != id }.map(\.nombre)
        let limpio = try validar(nombre, entre: otras)
        guard limpio != categoria.nombre else { return categoria }
        categoria.nombre = limpio
        categoria.modificado = ahora()
        try guardar(categorias: [categoria])
        return categoria
    }

    public func borrarCategoria(_ id: UUID) throws(ErrorInventario) {
        guard let categoria = categoria(id) else { throw .noEncontrado }
        let (borrada, productos) = categoria.borrando(
            conProductos: Array(todosProductos.values),
            ahora: ahora()
        )
        try guardar(categorias: [borrada], productos: productos)
    }

    // MARK: Productos

    @discardableResult
    public func crearProducto(
        nombre: String,
        en categoriaId: UUID,
        cantidad: Int = 0,
        umbralCompra: Int = Limites.umbralCompraPorDefecto,
        autoListaCompra: Bool = true
    ) throws(ErrorInventario) -> Producto {
        guard categoria(categoriaId) != nil else { throw .noEncontrado }
        let limpio = try validar(nombre, entre: productos(en: categoriaId).map(\.nombre))
        let nuevo = Producto(
            categoriaId: categoriaId,
            nombre: limpio,
            cantidad: cantidad,
            umbralCompra: umbralCompra,
            autoListaCompra: autoListaCompra,
            creado: ahora()
        )
        try guardar(productos: [nuevo])
        return nuevo
    }

    /// Lo que se cambia desde la pantalla de edición. Si nada cambia, no se guarda.
    @discardableResult
    public func editarProducto(
        _ id: UUID,
        nombre: String,
        cantidad: Int,
        umbralCompra: Int,
        autoListaCompra: Bool
    ) throws(ErrorInventario) -> Producto {
        guard let original = producto(id) else { throw .noEncontrado }
        let otros = productos(en: original.categoriaId).filter { $0.id != id }.map(\.nombre)
        let limpio = try validar(nombre, entre: otros)
        let momento = ahora()

        var editado = original
            .fijandoCantidad(cantidad, ahora: momento)
            .fijandoUmbralCompra(umbralCompra, ahora: momento)
        if editado.nombre != limpio {
            editado.nombre = limpio
            editado.modificado = momento
        }
        if editado.autoListaCompra != autoListaCompra {
            editado.autoListaCompra = autoListaCompra
            editado.modificado = momento
        }
        guard editado != original else { return original }
        try guardar(productos: [editado])
        return editado
    }

    /// Para los botones de más y menos: el cambio es relativo, no un valor final.
    @discardableResult
    public func ajustarCantidad(_ id: UUID, en cambio: Int) throws(ErrorInventario) -> Producto {
        guard let original = producto(id) else { throw .noEncontrado }
        let ajustado = original.ajustandoCantidad(en: cambio, ahora: ahora())
        guard ajustado != original else { return original }
        try guardar(productos: [ajustado])
        return ajustado
    }

    @discardableResult
    public func fijarListaManual(_ id: UUID, en valor: Bool) throws(ErrorInventario) -> Producto {
        guard var producto = producto(id) else { throw .noEncontrado }
        guard producto.enListaCompraManual != valor else { return producto }
        producto.enListaCompraManual = valor
        producto.modificado = ahora()
        try guardar(productos: [producto])
        return producto
    }

    public func borrarProducto(_ id: UUID) throws(ErrorInventario) {
        guard var producto = producto(id) else { throw .noEncontrado }
        let momento = ahora()
        producto.borrado = momento
        producto.modificado = momento
        try guardar(productos: [producto])
    }

    // MARK: Importación

    /// Añade lo que trae el archivo. Las categorías con el mismo nombre que una
    /// existente se juntan con ella; los productos que ya existen con el mismo
    /// nombre en su categoría se saltan. Todo se guarda de una vez.
    ///
    /// Los identificadores se generan de nuevo: reutilizar los del archivo
    /// podría pisar datos al importar dos veces o al importar algo ya borrado.
    @discardableResult
    public func importar(_ exportacion: Exportacion) throws(ErrorInventario) -> ResultadoImportacion {
        let momento = ahora()
        var resultado = ResultadoImportacion()
        var nuevasCategorias: [Categoria] = []
        var nuevosProductos: [Producto] = []

        var categoriaPorClave = Dictionary(
            categorias.map { (Nombres.clave($0.nombre), $0.id) },
            uniquingKeysWith: { primera, _ in primera }
        )
        var idImportadoAId: [UUID: UUID] = [:]

        for original in exportacion.categorias where !original.estaBorrada {
            guard case .success(let nombre) = Nombres.validar(original.nombre, existentes: []) else {
                resultado.noValidos += 1
                continue
            }
            let clave = Nombres.clave(nombre)
            if let existente = categoriaPorClave[clave] {
                idImportadoAId[original.id] = existente
                continue
            }
            let nueva = Categoria(nombre: nombre, creado: original.creado, modificado: momento)
            nuevasCategorias.append(nueva)
            categoriaPorClave[clave] = nueva.id
            idImportadoAId[original.id] = nueva.id
            resultado.categorias += 1
        }

        var clavesPorCategoria: [UUID: Set<String>] = [:]
        for original in exportacion.productos where !original.estaBorrado {
            guard let categoriaId = idImportadoAId[original.categoriaId],
                  case .success(let nombre) = Nombres.validar(original.nombre, existentes: [])
            else {
                resultado.noValidos += 1
                continue
            }
            let clave = Nombres.clave(nombre)
            var claves = clavesPorCategoria[categoriaId]
                ?? Set(productos(en: categoriaId).map { Nombres.clave($0.nombre) })
            guard !claves.contains(clave) else {
                resultado.repetidos += 1
                continue
            }
            claves.insert(clave)
            clavesPorCategoria[categoriaId] = claves
            nuevosProductos.append(Producto(
                categoriaId: categoriaId,
                nombre: nombre,
                cantidad: original.cantidad,
                umbralCompra: original.umbralCompra,
                autoListaCompra: original.autoListaCompra,
                enListaCompraManual: original.enListaCompraManual,
                creado: original.creado,
                modificado: momento
            ))
            resultado.productos += 1
        }

        try guardar(categorias: nuevasCategorias, productos: nuevosProductos)
        return resultado
    }

    // MARK: Auxiliares

    private func validar(_ nombre: String, entre existentes: [String]) throws(ErrorInventario) -> String {
        switch Nombres.validar(nombre, existentes: existentes) {
        case .success(let limpio): return limpio
        case .failure(let error): throw .nombre(error)
        }
    }

    private func guardar(categorias: [Categoria] = [], productos: [Producto] = []) throws(ErrorInventario) {
        guard !categorias.isEmpty || !productos.isEmpty else { return }
        do {
            try almacen.guardar(categorias: categorias, productos: productos)
        } catch {
            throw .guardado(String(describing: error))
        }
        for c in categorias { todasCategorias[c.id] = c }
        for p in productos { todosProductos[p.id] = p }
    }
}
