import AppIntents
import InventarioNucleo

/// Un producto del hogar abierto, tal como lo ven Siri y Atajos.
struct ProductoEntidad: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Producto"
    static let defaultQuery = ConsultaProductos()

    let id: UUID
    let nombre: String
    let categoria: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nombre)", subtitle: "\(categoria)")
    }

    @MainActor
    init(_ producto: Producto, en inventario: Inventario) {
        id = producto.id
        nombre = producto.nombre
        categoria = inventario.categoria(producto.categoriaId)?.nombre ?? ""
    }
}

struct ConsultaProductos: EntityStringQuery {
    @Dependency private var arranque: Arranque

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ProductoEntidad] {
        let inventario = try arranque.inventarioParaSiri()
        return identifiers.compactMap(inventario.producto).map { ProductoEntidad($0, en: inventario) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [ProductoEntidad] {
        let inventario = try arranque.inventarioParaSiri()
        return inventario.buscarProductos(string).map { ProductoEntidad($0, en: inventario) }
    }

    /// También son los nombres que Siri reconoce en las frases de los atajos.
    @MainActor
    func suggestedEntities() async throws -> [ProductoEntidad] {
        let inventario = try arranque.inventarioParaSiri()
        return inventario.todosLosProductos.map { ProductoEntidad($0, en: inventario) }
    }
}

struct CategoriaEntidad: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Categoría"
    static let defaultQuery = ConsultaCategorias()

    let id: UUID
    let nombre: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nombre)")
    }

    init(_ categoria: Categoria) {
        id = categoria.id
        nombre = categoria.nombre
    }
}

struct ConsultaCategorias: EntityStringQuery {
    @Dependency private var arranque: Arranque

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoriaEntidad] {
        let inventario = try arranque.inventarioParaSiri()
        return identifiers.compactMap(inventario.categoria).map(CategoriaEntidad.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoriaEntidad] {
        try arranque.inventarioParaSiri().buscarCategorias(string).map(CategoriaEntidad.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoriaEntidad] {
        try arranque.inventarioParaSiri().categorias.map(CategoriaEntidad.init)
    }
}
