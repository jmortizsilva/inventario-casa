import AppIntents
import InventarioNucleo
import OSLog

/// Para seguir en el registro del iPhone lo que recibe cada acción:
/// `log show --predicate 'subsystem == "com.jmortiz.inventario" AND category == "Siri"'`.
let registroSiri = Logger(subsystem: "com.jmortiz.inventario", category: "Siri")

// Los títulos, las frases y las preguntas son literales: Apple los lee al
// compilar. Están revisados en docs/textos-interfaz.md, apartado «Siri».
// Las respuestas vienen de `Textos.Siri`.

@MainActor
private func cambiar(
    _ entidad: ProductoEntidad,
    arranque: Arranque,
    _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto
) throws -> (antes: Producto, despues: Producto) {
    try cambiarProducto(entidad.id, nombre: entidad.nombre, arranque: arranque, cambio)
}

struct AnadirUnidades: AppIntent {
    static let title: LocalizedStringResource = "Añadir unidades"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Producto", requestValueDialog: "¿Qué producto?")
    var producto: ProductoEntidad

    @Parameter(title: "Unidades", inclusiveRange: (1, 999), requestValueDialog: "¿Cuántas unidades?")
    var unidades: Int

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Añadir \(\.$unidades) de \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cambiado = try cambiar(producto, arranque: arranque) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: unidades)
        }
        return .result(dialog: "\(Textos.Siri.cambio(antes: cambiado.antes, despues: cambiado.despues))")
    }
}

struct QuitarUnidades: AppIntent {
    static let title: LocalizedStringResource = "Quitar unidades"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Producto", requestValueDialog: "¿Qué producto?")
    var producto: ProductoEntidad

    @Parameter(title: "Unidades", inclusiveRange: (1, 999), requestValueDialog: "¿Cuántas unidades?")
    var unidades: Int

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Quitar \(\.$unidades) de \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cambiado = try cambiar(producto, arranque: arranque) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: -unidades)
        }
        return .result(dialog: "\(Textos.Siri.cambio(antes: cambiado.antes, despues: cambiado.despues))")
    }
}

struct CambiarCantidad: AppIntent {
    static let title: LocalizedStringResource = "Cambiar la cantidad"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Producto", requestValueDialog: "¿Qué producto?")
    var producto: ProductoEntidad

    @Parameter(title: "Unidades", inclusiveRange: (0, 999), requestValueDialog: "¿Cuántas unidades hay?")
    var unidades: Int

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Poner \(\.$producto) a \(\.$unidades)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let cambiado = try cambiar(producto, arranque: arranque) { inventario, producto throws(ErrorInventario) in
            try inventario.editarProducto(
                producto.id,
                nombre: producto.nombre,
                cantidad: unidades,
                umbralCompra: producto.umbralCompra,
                autoListaCompra: producto.autoListaCompra
            )
        }
        return .result(dialog: "\(Textos.Siri.cambio(antes: cambiado.antes, despues: cambiado.despues))")
    }
}

struct ConsultarProducto: AppIntent {
    static let title: LocalizedStringResource = "Consultar un producto"
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Producto", requestValueDialog: "¿Qué producto?")
    var producto: ProductoEntidad

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Consultar \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let inventario = try arranque.inventarioParaSiri()
        guard let actual = inventario.producto(producto.id) else {
            throw ErrorSiri.noEncontrado(producto.nombre, arranque: arranque)
        }
        return .result(dialog: "\(Textos.Siri.resultado(actual))")
    }
}

struct CrearProducto: AppIntent {
    static let title: LocalizedStringResource = "Crear producto"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Nombre", requestValueDialog: "¿Cómo se llama?")
    var nombre: String

    // Texto y no `CategoriaEntidad`: con una entidad, Siri pregunta ofreciendo
    // una lista y, si se contesta otra cosa, reinicia la acción y vuelve a
    // preguntar sin fin (probado en el iPhone con iOS 27). Con texto, la
    // categoría se busca aquí, sin tildes y en singular o plural.
    @Parameter(title: "Categoría", requestValueDialog: "¿En qué categoría?")
    var categoria: String

    @Parameter(title: "Unidades", inclusiveRange: (0, 999), requestValueDialog: "¿Cuántas unidades?")
    var unidades: Int

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Crear \(\.$nombre) en \(\.$categoria) con \(\.$unidades)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let respuesta = try crearProductoPorVoz(nombre: nombre, categoria: categoria, unidades: unidades, arranque: arranque)
        return .result(dialog: "\(respuesta)")
    }
}

struct EliminarProducto: AppIntent {
    static let title: LocalizedStringResource = "Eliminar producto"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Producto", requestValueDialog: "¿Qué producto?")
    var producto: ProductoEntidad

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Eliminar \(\.$producto)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pregunta = Textos.Siri.confirmarEliminar(producto.nombre, de: producto.categoria)
        guard try await $producto.requestConfirmation(for: producto, dialog: "\(pregunta)") else {
            return .result(dialog: "\(Textos.Siri.noEliminado(producto.nombre))")
        }
        _ = try cambiar(producto, arranque: arranque) { inventario, producto throws(ErrorInventario) in
            try inventario.borrarProducto(producto.id)
            return producto
        }
        return .result(dialog: "\(Textos.Siri.eliminado(producto.nombre))")
    }
}
