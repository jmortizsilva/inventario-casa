import Foundation

/// Dónde se guardan los datos. No decide nada: carga todo, incluido lo borrado,
/// y guarda lo que le pasan.
@MainActor
public protocol Almacen: AnyObject {
    func cargarCategorias() throws -> [Categoria]
    func cargarProductos() throws -> [Producto]
    func cargarPendientes() throws -> Pendientes
    func cargarEstado() throws -> EstadoSincronizacion

    /// Crea o sustituye por `id`. Si vienen `pendientes` o `estado`, sustituyen
    /// a los guardados. Se guarda todo o nada: un cambio guardado sin su
    /// pendiente no se enviaría nunca, y nadie se enteraría.
    func guardar(
        categorias: [Categoria],
        productos: [Producto],
        pendientes: Pendientes?,
        estado: EstadoSincronizacion?
    ) throws

    /// Borra categorías, productos y pendientes, y deja `estado`. Para empezar
    /// de cero con el inventario de un hogar.
    func vaciar(estado: EstadoSincronizacion) throws
}

extension Almacen {
    public func guardar(categorias: [Categoria], productos: [Producto]) throws {
        try guardar(categorias: categorias, productos: productos, pendientes: nil, estado: nil)
    }
}

/// Para pruebas y vistas previas.
@MainActor
public final class AlmacenEnMemoria: Almacen {
    public private(set) var categorias: [UUID: Categoria] = [:]
    public private(set) var productos: [UUID: Producto] = [:]
    public private(set) var pendientes = Pendientes()
    public private(set) var estado = EstadoSincronizacion.sinHogar
    public private(set) var vecesGuardado = 0
    public var fallarAlGuardar = false

    public struct FalloSimulado: Error {}

    public init(categorias: [Categoria] = [], productos: [Producto] = []) {
        for c in categorias { self.categorias[c.id] = c }
        for p in productos { self.productos[p.id] = p }
    }

    public func cargarCategorias() throws -> [Categoria] { Array(categorias.values) }
    public func cargarProductos() throws -> [Producto] { Array(productos.values) }
    public func cargarPendientes() throws -> Pendientes { pendientes }
    public func cargarEstado() throws -> EstadoSincronizacion { estado }

    public func guardar(
        categorias: [Categoria],
        productos: [Producto],
        pendientes: Pendientes?,
        estado: EstadoSincronizacion?
    ) throws {
        if fallarAlGuardar { throw FalloSimulado() }
        for c in categorias { self.categorias[c.id] = c }
        for p in productos { self.productos[p.id] = p }
        if let pendientes { self.pendientes = pendientes }
        if let estado { self.estado = estado }
        vecesGuardado += 1
    }

    public func vaciar(estado: EstadoSincronizacion) throws {
        if fallarAlGuardar { throw FalloSimulado() }
        categorias = [:]
        productos = [:]
        pendientes = Pendientes()
        self.estado = estado
        vecesGuardado += 1
    }
}
