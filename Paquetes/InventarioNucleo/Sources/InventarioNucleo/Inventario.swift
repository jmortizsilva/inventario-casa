import Foundation
import Observation

public enum ErrorInventario: Error, Equatable, Sendable {
    case nombre(ErrorNombre)
    case noEncontrado
    case carga(String)
    case guardado(String)
}

/// Lo último eliminado, mientras se puede deshacer.
public enum Eliminacion: Equatable, Sendable {
    case producto(Producto)
    /// Con los productos que se fueron con ella, tal como estaban.
    case categoria(Categoria, productos: [Producto])

    public var nombre: String {
        switch self {
        case .producto(let p): p.nombre
        case .categoria(let c, _): c.nombre
        }
    }
}

/// Estado del inventario y todas las operaciones que lo cambian. Primero guarda
/// en el almacén y solo si sale bien actualiza lo que ve la interfaz, para que
/// pantalla y datos guardados no difieran tras un error.
@MainActor
@Observable
public final class Inventario {
    private let almacen: Almacen
    private let ahora: () -> Date
    // Incluyen lo borrado: la sincronización tiene que enviar las bajas.
    private var todasCategorias: [UUID: Categoria] = [:]
    private var todosProductos: [UUID: Producto] = [:]

    /// Lo que falta por enviar al servidor. Vacía mientras no haya hogar.
    public private(set) var pendientes = Pendientes()
    public private(set) var estado = EstadoSincronizacion.sinHogar

    /// Lo que se puede deshacer. Se olvida con cualquier otro cambio hecho
    /// aquí (no con lo que llega sincronizando) y al salir de la pantalla.
    public private(set) var ultimaEliminacion: Eliminacion?

    /// Unido a un hogar: cada cambio se anota para enviarlo.
    public var conHogar: Bool { estado.hogarId != nil }

    public init(almacen: Almacen, ahora: @escaping () -> Date = Date.init) {
        self.almacen = almacen
        self.ahora = ahora
    }

    public func cargar() throws(ErrorInventario) {
        do {
            let categorias = try almacen.cargarCategorias()
            let productos = try almacen.cargarProductos()
            pendientes = try almacen.cargarPendientes()
            estado = try almacen.cargarEstado()
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

    /// Todos los productos sin borrar, de todas las categorías.
    public var todosLosProductos: [Producto] {
        todosProductos.values
            .filter { !$0.estaBorrado }
            .sorted { Nombres.vaAntes($0.nombre, $1.nombre) }
    }

    public func buscarProductos(_ texto: String) -> [Producto] {
        Busqueda.productos(texto, en: Array(todosProductos.values))
    }

    /// Cómo se nombra el producto al decírselo a Siri: el nombre, y la
    /// categoría solo si otro producto se llama igual («Leche, Nevera»).
    public func nombreParaSiri(_ producto: Producto) -> String {
        let clave = Nombres.clave(producto.nombre)
        let repetido = todosLosProductos.contains { $0.id != producto.id && Nombres.clave($0.nombre) == clave }
        guard repetido, let categoria = categoria(producto.categoriaId) else { return producto.nombre }
        return "\(producto.nombre), \(categoria.nombre)"
    }

    /// Lo contrario: lo que se eligió o se dijo, de vuelta a productos. Primero
    /// los que se nombran así exactamente; si no hay, la búsqueda normal.
    public func productosParaSiri(_ texto: String) -> [Producto] {
        let clave = Nombres.clave(texto)
        let exactos = todosLosProductos.filter { Nombres.clave(nombreParaSiri($0)) == clave }
        return exactos.isEmpty ? buscarProductos(texto) : exactos
    }

    public func buscarCategorias(_ texto: String) -> [Categoria] {
        Busqueda.categorias(texto, en: categorias)
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
        try guardar(categorias: [nueva]) { $0.anotar(categoria: nueva.id) }
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
        try guardar(categorias: [categoria]) { $0.anotar(categoria: id) }
        return categoria
    }

    public func borrarCategoria(_ id: UUID) throws(ErrorInventario) {
        guard let categoria = categoria(id) else { throw .noEncontrado }
        let (borrada, productos) = categoria.borrando(
            conProductos: Array(todosProductos.values),
            ahora: ahora()
        )
        let antes = productos.compactMap { todosProductos[$0.id] }
        try guardar(categorias: [borrada], productos: productos) { cola in
            cola.anotar(categoria: id)
            for producto in productos { cola.anotar(producto: producto.id) }
        }
        ultimaEliminacion = .categoria(categoria, productos: antes)
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
        // Las unidades de un producto nuevo se fijan: sin esto el servidor
        // lo crearía con 0.
        try guardar(productos: [nuevo]) {
            $0.anotar(fijada: CantidadFijada(cantidad: nuevo.cantidad, en: nuevo.creado), producto: nuevo.id)
        }
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
            .fijandoCantidad(cantidad)
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
        try guardar(productos: [editado]) { cola in
            if editado.cantidad != original.cantidad {
                cola.anotar(fijada: CantidadFijada(cantidad: editado.cantidad, en: momento), producto: id)
            } else {
                cola.anotar(producto: id)
            }
        }
        return editado
    }

    /// Para los botones de más y menos: el cambio es relativo, no un valor final.
    @discardableResult
    public func ajustarCantidad(_ id: UUID, en cambio: Int) throws(ErrorInventario) -> Producto {
        guard let original = producto(id) else { throw .noEncontrado }
        let momento = ahora()
        let ajustado = original.ajustandoCantidad(en: cambio)
        guard ajustado != original else { return original }
        // Se manda lo que cambió de verdad, no lo pedido: en 0, un «−1» no
        // cambia nada aquí y tampoco tiene que restar en el servidor.
        let movimiento = Movimiento(
            productoId: id, cambio: ajustado.cantidad - original.cantidad, momento: momento
        )
        try guardar(productos: [ajustado]) { $0.anotar(movimiento) }
        return ajustado
    }

    @discardableResult
    public func fijarListaManual(_ id: UUID, en valor: Bool) throws(ErrorInventario) -> Producto {
        guard var producto = producto(id) else { throw .noEncontrado }
        guard producto.enListaCompraManual != valor else { return producto }
        producto.enListaCompraManual = valor
        producto.modificado = ahora()
        try guardar(productos: [producto]) { $0.anotar(producto: id) }
        return producto
    }

    public func borrarProducto(_ id: UUID) throws(ErrorInventario) {
        guard var producto = producto(id) else { throw .noEncontrado }
        let momento = ahora()
        let antes = producto
        producto.borrado = momento
        producto.modificado = momento
        try guardar(productos: [producto]) { $0.anotar(producto: id) }
        ultimaEliminacion = .producto(antes)
    }

    // MARK: Deshacer

    public func olvidarEliminacion() {
        ultimaEliminacion = nil
    }

    /// Recupera lo último eliminado, con hora de ahora para que gane en el
    /// servidor, y marcado para restaurar: sin eso el servidor no deja volver
    /// nada borrado. Devuelve lo recuperado, o nil si no había nada.
    @discardableResult
    public func deshacerEliminacion() throws(ErrorInventario) -> Eliminacion? {
        guard let eliminacion = ultimaEliminacion else { return nil }
        let momento = ahora()
        func recuperado(_ p: Producto) -> Producto {
            var copia = todosProductos[p.id] ?? p
            copia.borrado = nil
            copia.modificado = momento
            return copia
        }
        switch eliminacion {
        case .producto(let original):
            let producto = recuperado(original)
            try guardar(productos: [producto]) { cola in
                cola.anotar(producto: producto.id)
                cola.anotar(restaurar: producto.id)
            }
        case .categoria(let original, let originales):
            var categoria = todasCategorias[original.id] ?? original
            categoria.borrado = nil
            categoria.modificado = momento
            let productos = originales.map(recuperado)
            try guardar(categorias: [categoria], productos: productos) { cola in
                cola.anotar(categoria: categoria.id)
                cola.anotar(restaurar: categoria.id)
                for producto in productos {
                    cola.anotar(producto: producto.id)
                    cola.anotar(restaurar: producto.id)
                }
            }
        }
        return eliminacion
    }

    // MARK: Importación

    /// Lo que se lleva a un hogar nuevo, para `importar` en él. Nil si no hay
    /// nada que copiar.
    ///
    /// Los productos llegan con cantidad 0 y fuera de la lista manual: lo que
    /// hay en la despensa de otra casa no dice nada de esta.
    public func copia(_ que: QueCopiar) -> Exportacion? {
        let categorias = categorias
        guard que != .nada, !categorias.isEmpty else { return nil }
        let productos = que == .categoriasYProductos
            ? categorias.flatMap { productos(en: $0.id) }.map {
                Producto(
                    categoriaId: $0.categoriaId,
                    nombre: $0.nombre,
                    umbralCompra: $0.umbralCompra,
                    autoListaCompra: $0.autoListaCompra,
                    creado: $0.creado
                )
            }
            : []
        return Exportacion(categorias: categorias, productos: productos)
    }

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

        try guardar(categorias: nuevasCategorias, productos: nuevosProductos) { cola in
            for categoria in nuevasCategorias { cola.anotar(categoria: categoria.id) }
            for producto in nuevosProductos {
                cola.anotar(fijada: CantidadFijada(cantidad: producto.cantidad, en: momento), producto: producto.id)
            }
        }
        return resultado
    }

    // MARK: Sincronización

    /// Productos sin borrar, para decir cuántos hay antes de unirse a un hogar.
    public var cuantosProductos: Int {
        todosProductos.values.count { !$0.estaBorrado }
    }

    /// El siguiente envío. Vacío si no queda nada en la cola.
    public func loteParaEnviar(maximo: Int = Sincronizacion.maximoPorLote) -> Api.Lote {
        Sincronizacion.lote(pendientes, categorias: todasCategorias, productos: todosProductos, maximo: maximo)
    }

    /// Tras la respuesta a `enviado`: saca de la cola lo confirmado y se queda
    /// con la versión definitiva de cada cosa. No mueve la revisión.
    public func confirmarEnvio(_ enviado: Api.Lote, respuesta: Api.RespuestaEnvio) throws(ErrorInventario) {
        let cola = Sincronizacion.confirmar(
            pendientes, enviado: enviado, categorias: todasCategorias, productos: todosProductos
        )
        let (categorias, productos) = Sincronizacion.fusionar(
            categorias: respuesta.categorias,
            productos: respuesta.productos,
            en: (todasCategorias, todosProductos),
            pendientes: cola
        )
        try guardarEnAlmacen(categorias: categorias, productos: productos, pendientes: cola, estado: nil)
    }

    /// Lo bajado con `GET /sincronizar`, y la revisión hasta la que llega.
    public func aplicarNovedades(_ novedades: Api.Novedades) throws(ErrorInventario) {
        let (categorias, productos) = Sincronizacion.fusionar(
            categorias: novedades.categorias,
            productos: novedades.productos,
            en: (todasCategorias, todosProductos),
            pendientes: pendientes
        )
        var nuevo = estado
        nuevo.revision = novedades.revision
        try guardarEnAlmacen(categorias: categorias, productos: productos, pendientes: nil, estado: nuevo)
    }

    /// Empezar a sincronizar con un hogar, recién creado o recién unido.
    ///
    /// Con `conservando`, todo lo del iPhone entra en la cola. Las unidades se
    /// fijan con la hora de su último cambio aquí y no con la de ahora: si se
    /// vuelve a un hogar donde otra persona las cambió después, gana lo de
    /// ella en lugar de lo que se quedó en este iPhone al salir.
    ///
    /// Sin `conservando`, el iPhone se vacía y el inventario llega entero del hogar.
    public func unirAHogar(_ hogarId: String, conservando: Bool) throws(ErrorInventario) {
        let estadoNuevo = EstadoSincronizacion(hogarId: hogarId, revision: 0)
        guard conservando else {
            do {
                try almacen.vaciar(estado: estadoNuevo)
            } catch {
                throw .guardado(String(describing: error))
            }
            todasCategorias = [:]
            todosProductos = [:]
            pendientes = Pendientes()
            estado = estadoNuevo
            return
        }
        var cola = Pendientes()
        for categoria in categorias { cola.anotar(categoria: categoria.id) }
        for producto in todosProductos.values where !producto.estaBorrado {
            cola.anotar(fijada: CantidadFijada(cantidad: producto.cantidad, en: producto.modificado), producto: producto.id)
        }
        try guardarEnAlmacen(categorias: [], productos: [], pendientes: cola, estado: estadoNuevo)
    }

    /// Al salir del hogar o cerrar sesión: el inventario se queda en el iPhone
    /// y deja de sincronizarse. Lo que no se envió se pierde para el hogar.
    public func separarDelHogar() throws(ErrorInventario) {
        try guardarEnAlmacen(categorias: [], productos: [], pendientes: Pendientes(), estado: .sinHogar)
    }

    // MARK: Auxiliares

    private func validar(_ nombre: String, entre existentes: [String]) throws(ErrorInventario) -> String {
        switch Nombres.validar(nombre, existentes: existentes) {
        case .success(let limpio): return limpio
        case .failure(let error): throw .nombre(error)
        }
    }

    /// `anotar` dice qué entra en la cola. Solo se usa si hay hogar, y la cola
    /// nueva se guarda en la misma operación que el cambio.
    private func guardar(
        categorias: [Categoria] = [],
        productos: [Producto] = [],
        anotar: (inout Pendientes) -> Void = { _ in }
    ) throws(ErrorInventario) {
        guard !categorias.isEmpty || !productos.isEmpty else { return }
        // Cualquier otro cambio hecho aquí cierra la posibilidad de deshacer.
        ultimaEliminacion = nil
        var cola: Pendientes?
        if conHogar {
            var nueva = pendientes
            anotar(&nueva)
            cola = nueva
        }
        try guardarEnAlmacen(categorias: categorias, productos: productos, pendientes: cola, estado: nil)
    }

    /// Lo único que escribe en el almacén. Primero el almacén y solo si sale
    /// bien lo que ve la interfaz.
    private func guardarEnAlmacen(
        categorias: [Categoria],
        productos: [Producto],
        pendientes: Pendientes?,
        estado: EstadoSincronizacion?
    ) throws(ErrorInventario) {
        do {
            try almacen.guardar(categorias: categorias, productos: productos, pendientes: pendientes, estado: estado)
        } catch {
            throw .guardado(String(describing: error))
        }
        for c in categorias { todasCategorias[c.id] = c }
        for p in productos { todosProductos[p.id] = p }
        if let pendientes { self.pendientes = pendientes }
        if let estado { self.estado = estado }
    }
}

/// Al crear un hogar teniendo ya otro: qué se copia del actual al nuevo.
public enum QueCopiar: CaseIterable, Sendable {
    case nada
    case categorias
    case categoriasYProductos
}
