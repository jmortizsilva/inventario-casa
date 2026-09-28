import AppIntents
import InventarioNucleo

// Los títulos, las frases y las preguntas son literales: Apple los lee al
// compilar. Están revisados en docs/textos-interfaz.md, apartado «Siri».
// Las respuestas vienen de `Textos.Siri`.

/// Lo común a las acciones sobre un producto que ya existe: buscarlo en el
/// hogar abierto, cambiarlo y enviar el cambio sin que Siri espere a la red.
@MainActor
private func cambiar(
    _ entidad: ProductoEntidad,
    arranque: Arranque,
    _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto
) throws -> Producto {
    let inventario = try arranque.inventarioParaSiri()
    guard let producto = inventario.producto(entidad.id) else {
        throw ErrorSiri.noEncontrado(entidad.nombre, arranque: arranque)
    }
    let cambiado: Producto
    do {
        cambiado = try cambio(inventario, producto)
    } catch {
        throw ErrorSiri.noGuardado
    }
    arranque.enviarEnSegundoPlano()
    return cambiado
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
        return .result(dialog: "\(Textos.Siri.resultado(cambiado))")
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
        return .result(dialog: "\(Textos.Siri.resultado(cambiado))")
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
        return .result(dialog: "\(Textos.Siri.resultado(cambiado))")
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

    @Parameter(title: "Categoría", requestValueDialog: "¿En qué categoría?")
    var categoria: CategoriaEntidad

    @Parameter(title: "Unidades", inclusiveRange: (0, 999), requestValueDialog: "¿Cuántas unidades?")
    var unidades: Int

    @Dependency private var arranque: Arranque

    static var parameterSummary: some ParameterSummary {
        Summary("Crear \(\.$nombre) en \(\.$categoria) con \(\.$unidades)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let inventario = try arranque.inventarioParaSiri()
        guard inventario.categoria(categoria.id) != nil else {
            throw ErrorSiri.noEncontrado(categoria.nombre, arranque: arranque)
        }
        let creado: Producto
        do {
            creado = try inventario.crearProducto(nombre: nombre, en: categoria.id, cantidad: unidades)
        } catch .nombre(let error) {
            throw ErrorSiri(
                mensaje: Textos.Errores.nombreProducto(error, categoria: categoria.nombre)
                    ?? Textos.Errores.noGuardadoMensaje
            )
        } catch {
            throw ErrorSiri.noGuardado
        }
        arranque.enviarEnSegundoPlano()
        return .result(dialog: "\(Textos.Siri.creado(creado.nombre, en: categoria.nombre))")
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
