import Foundation

/// Dónde se guardan los datos. No decide nada: carga todo, incluido lo borrado,
/// y guarda lo que le pasan.
@MainActor
public protocol Almacen: AnyObject {
    func cargarCategorias() throws -> [Categoria]
    func cargarProductos() throws -> [Producto]
    /// Crea o sustituye por `id`. Se guarda todo o nada.
    func guardar(categorias: [Categoria], productos: [Producto]) throws
}

/// Para pruebas y vistas previas.
@MainActor
public final class AlmacenEnMemoria: Almacen {
    public private(set) var categorias: [UUID: Categoria] = [:]
    public private(set) var productos: [UUID: Producto] = [:]
    public private(set) var vecesGuardado = 0
    public var fallarAlGuardar = false

    public struct FalloSimulado: Error {}

    public init(categorias: [Categoria] = [], productos: [Producto] = []) {
        for c in categorias { self.categorias[c.id] = c }
        for p in productos { self.productos[p.id] = p }
    }

    public func cargarCategorias() throws -> [Categoria] { Array(categorias.values) }
    public func cargarProductos() throws -> [Producto] { Array(productos.values) }

    public func guardar(categorias: [Categoria], productos: [Producto]) throws {
        if fallarAlGuardar { throw FalloSimulado() }
        for c in categorias { self.categorias[c.id] = c }
        for p in productos { self.productos[p.id] = p }
        vecesGuardado += 1
    }
}
