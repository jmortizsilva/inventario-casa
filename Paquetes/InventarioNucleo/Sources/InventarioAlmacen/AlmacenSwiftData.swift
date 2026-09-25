import Foundation
import SwiftData
import InventarioNucleo

@MainActor
public final class AlmacenSwiftData: Almacen {
    private let contenedor: ModelContainer
    private let contexto: ModelContext

    /// El almacén de la app, en el disco del móvil.
    public static func enDisco() throws -> AlmacenSwiftData {
        try AlmacenSwiftData(configuracion: ModelConfiguration("Inventario"))
    }

    /// Para pruebas: se pierde al cerrar.
    public static func enMemoria() throws -> AlmacenSwiftData {
        try AlmacenSwiftData(configuracion: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private init(configuracion: ModelConfiguration) throws {
        contenedor = try ModelContainer(
            for: Schema(versionedSchema: EsquemaV1.self),
            migrationPlan: PlanMigracion.self,
            configurations: configuracion
        )
        contexto = ModelContext(contenedor)
        // Sin guardado automático: cada `guardar` es todo o nada.
        contexto.autosaveEnabled = false
    }

    /// Un segundo almacén sobre los mismos datos, como si se reabriera la app.
    func reabrir() -> AlmacenSwiftData {
        AlmacenSwiftData(contenedor: contenedor)
    }

    private init(contenedor: ModelContainer) {
        self.contenedor = contenedor
        contexto = ModelContext(contenedor)
        contexto.autosaveEnabled = false
    }

    public func cargarCategorias() throws -> [Categoria] {
        try contexto.fetch(FetchDescriptor<CategoriaGuardada>()).map(\.comoCategoria)
    }

    public func cargarProductos() throws -> [Producto] {
        try contexto.fetch(FetchDescriptor<ProductoGuardado>()).map(\.comoProducto)
    }

    public func guardar(categorias: [Categoria], productos: [Producto]) throws {
        do {
            for categoria in categorias {
                if let existente = try buscarCategoria(categoria.id) {
                    existente.copiar(categoria)
                } else {
                    contexto.insert(CategoriaGuardada(categoria))
                }
            }
            for producto in productos {
                if let existente = try buscarProducto(producto.id) {
                    existente.copiar(producto)
                } else {
                    contexto.insert(ProductoGuardado(producto))
                }
            }
            try contexto.save()
        } catch {
            contexto.rollback()
            throw error
        }
    }

    private func buscarCategoria(_ id: UUID) throws -> CategoriaGuardada? {
        var descriptor = FetchDescriptor<CategoriaGuardada>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try contexto.fetch(descriptor).first
    }

    private func buscarProducto(_ id: UUID) throws -> ProductoGuardado? {
        var descriptor = FetchDescriptor<ProductoGuardado>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try contexto.fetch(descriptor).first
    }
}

// MARK: Conversión entre el modelo del núcleo y el de SwiftData

extension CategoriaGuardada {
    convenience init(_ c: Categoria) {
        self.init(id: c.id, nombre: c.nombre, creado: c.creado, modificado: c.modificado, borrado: c.borrado)
    }

    func copiar(_ c: Categoria) {
        nombre = c.nombre
        modificado = c.modificado
        borrado = c.borrado
    }

    var comoCategoria: Categoria {
        Categoria(id: id, nombre: nombre, creado: creado, modificado: modificado, borrado: borrado)
    }
}

extension ProductoGuardado {
    convenience init(_ p: Producto) {
        self.init(
            id: p.id, categoriaId: p.categoriaId, nombre: p.nombre, cantidad: p.cantidad,
            umbralCompra: p.umbralCompra, autoListaCompra: p.autoListaCompra,
            enListaCompraManual: p.enListaCompraManual, creado: p.creado,
            modificado: p.modificado, borrado: p.borrado
        )
    }

    func copiar(_ p: Producto) {
        categoriaId = p.categoriaId
        nombre = p.nombre
        cantidad = p.cantidad
        umbralCompra = p.umbralCompra
        autoListaCompra = p.autoListaCompra
        enListaCompraManual = p.enListaCompraManual
        modificado = p.modificado
        borrado = p.borrado
    }

    var comoProducto: Producto {
        Producto(
            id: id, categoriaId: categoriaId, nombre: nombre, cantidad: cantidad,
            umbralCompra: umbralCompra, autoListaCompra: autoListaCompra,
            enListaCompraManual: enListaCompraManual, creado: creado,
            modificado: modificado, borrado: borrado
        )
    }
}
