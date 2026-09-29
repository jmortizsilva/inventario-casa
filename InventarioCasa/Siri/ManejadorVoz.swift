import Foundation
import Intents
import InventarioNucleo

/// Atiende las acciones de SiriKit, las que se guardan con «Añadir a Siri»
/// (definidas en `Voz.intentdefinition`). Existen porque las frases de
/// `Atajos` no llegan a la app en el iPhone y las frases que elige cada
/// persona sí (ver CLAUDE.md). Lo que hacen está en `OperacionesSiri`, igual
/// que las acciones de App Intents.
///
/// iOS pide el manejador al delegado de la app (`application(_:handlerFor:)`)
/// en el hilo principal; los métodos asíncronos siguen en él.
@MainActor
final class ManejadorVoz: NSObject {
    private var arranque: Arranque { .compartido }

    // MARK: Producto

    private func voz(_ producto: Producto, en inventario: Inventario) -> ProductoVoz {
        let voz = ProductoVoz(identifier: producto.id.uuidString, display: producto.nombre)
        voz.subtitleString = inventario.categoria(producto.categoriaId)?.nombre
        return voz
    }

    /// Los productos del hogar abierto: Siri empareja con ellos lo que se dice.
    fileprivate func opciones() throws -> INObjectCollection<ProductoVoz> {
        let inventario = try arranque.inventarioParaSiri()
        return INObjectCollection(items: inventario.todosLosProductos.map { voz($0, en: inventario) })
    }

    /// Si Siri no lo emparejó con una opción, llega solo lo dicho, y se busca
    /// igual que en la app. Sin coincidencias se da por bueno: al atenderlo
    /// falla con «No encuentro…», que dice más que volver a preguntar.
    fileprivate func resolver(_ dicho: ProductoVoz?) -> ProductoVozResolutionResult {
        guard let dicho else { return .needsValue() }
        guard let inventario = try? arranque.inventarioParaSiri() else { return .success(with: dicho) }
        if let id = dicho.identifier.flatMap(UUID.init(uuidString:)), inventario.producto(id) != nil {
            return .success(with: dicho)
        }
        let encontrados = inventario.buscarProductos(dicho.displayString)
        registroSiri.info("Buscar producto «\(dicho.displayString, privacy: .public)»: \(encontrados.count) encontrados")
        switch encontrados.count {
        case 0: return .success(with: dicho)
        case 1: return .success(with: voz(encontrados[0], en: inventario))
        default: return .disambiguation(with: encontrados.map { voz($0, en: inventario) })
        }
    }

    /// El producto elegido, o el error con lo que dice Siri.
    fileprivate func elegido(_ dicho: ProductoVoz?) throws -> (id: UUID, nombre: String) {
        let nombre = dicho?.displayString ?? ""
        guard let id = dicho?.identifier.flatMap(UUID.init(uuidString:)) else {
            throw ErrorSiri.noEncontrado(nombre, arranque: arranque)
        }
        return (id, nombre)
    }

    /// Suma (o resta) unidades, o las fija. Devuelve lo que contesta Siri.
    fileprivate func cambiarUnidades(_ dicho: ProductoVoz?, _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto) -> (ok: Bool, texto: String) {
        do {
            let (id, nombre) = try elegido(dicho)
            return (true, Textos.Siri.resultado(try cambiarProducto(id, nombre: nombre, arranque: arranque, cambio)))
        } catch {
            return (false, (error as? ErrorSiri)?.mensaje ?? Textos.Errores.noGuardadoMensaje)
        }
    }
}

// MARK: Crear producto

extension ManejadorVoz: @preconcurrency CrearProductoVozIntentHandling {
    func resolveNombre(for intent: CrearProductoVozIntent) async -> INStringResolutionResult {
        guard let nombre = intent.nombre, !Nombres.limpiar(nombre).isEmpty else { return .needsValue() }
        return .success(with: nombre)
    }

    func resolveCategoria(for intent: CrearProductoVozIntent) async -> INStringResolutionResult {
        guard let categoria = intent.categoria, !Nombres.limpiar(categoria).isEmpty else { return .needsValue() }
        return .success(with: categoria)
    }

    func resolveUnidades(for intent: CrearProductoVozIntent) async -> CrearProductoVozUnidadesResolutionResult {
        guard let unidades = intent.unidades?.intValue else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: CrearProductoVozIntent) async -> CrearProductoVozIntentResponse {
        do {
            let texto = try crearProductoPorVoz(
                nombre: intent.nombre ?? "",
                categoria: intent.categoria ?? "",
                unidades: intent.unidades?.intValue ?? 0,
                arranque: arranque
            )
            return .success(texto: texto)
        } catch {
            return .failure(texto: (error as? ErrorSiri)?.mensaje ?? Textos.Errores.noGuardadoMensaje)
        }
    }
}

// MARK: Añadir, quitar y cambiar unidades

extension ManejadorVoz: @preconcurrency AnadirUnidadesVozIntentHandling {
    func provideProductoOptionsCollection(for intent: AnadirUnidadesVozIntent) async throws -> INObjectCollection<ProductoVoz> {
        try opciones()
    }

    func resolveProducto(for intent: AnadirUnidadesVozIntent) async -> ProductoVozResolutionResult {
        resolver(intent.producto)
    }

    func resolveUnidades(for intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozUnidadesResolutionResult {
        guard let unidades = intent.unidades?.intValue else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozIntentResponse {
        let unidades = intent.unidades?.intValue ?? 1
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: unidades)
        }
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

extension ManejadorVoz: @preconcurrency QuitarUnidadesVozIntentHandling {
    func provideProductoOptionsCollection(for intent: QuitarUnidadesVozIntent) async throws -> INObjectCollection<ProductoVoz> {
        try opciones()
    }

    func resolveProducto(for intent: QuitarUnidadesVozIntent) async -> ProductoVozResolutionResult {
        resolver(intent.producto)
    }

    func resolveUnidades(for intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozUnidadesResolutionResult {
        guard let unidades = intent.unidades?.intValue else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozIntentResponse {
        let unidades = intent.unidades?.intValue ?? 1
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: -unidades)
        }
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

extension ManejadorVoz: @preconcurrency CambiarCantidadVozIntentHandling {
    func provideProductoOptionsCollection(for intent: CambiarCantidadVozIntent) async throws -> INObjectCollection<ProductoVoz> {
        try opciones()
    }

    func resolveProducto(for intent: CambiarCantidadVozIntent) async -> ProductoVozResolutionResult {
        resolver(intent.producto)
    }

    func resolveUnidades(for intent: CambiarCantidadVozIntent) async -> CambiarCantidadVozUnidadesResolutionResult {
        guard let unidades = intent.unidades?.intValue else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: CambiarCantidadVozIntent) async -> CambiarCantidadVozIntentResponse {
        let unidades = intent.unidades?.intValue ?? 0
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.editarProducto(
                producto.id,
                nombre: producto.nombre,
                cantidad: unidades,
                umbralCompra: producto.umbralCompra,
                autoListaCompra: producto.autoListaCompra
            )
        }
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

// MARK: Consultar y eliminar

extension ManejadorVoz: @preconcurrency ConsultarProductoVozIntentHandling {
    func provideProductoOptionsCollection(for intent: ConsultarProductoVozIntent) async throws -> INObjectCollection<ProductoVoz> {
        try opciones()
    }

    func resolveProducto(for intent: ConsultarProductoVozIntent) async -> ProductoVozResolutionResult {
        resolver(intent.producto)
    }

    func handle(intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozIntentResponse {
        do {
            let (id, nombre) = try elegido(intent.producto)
            guard let producto = try arranque.inventarioParaSiri().producto(id) else {
                throw ErrorSiri.noEncontrado(nombre, arranque: arranque)
            }
            return .success(texto: Textos.Siri.resultado(producto))
        } catch {
            return .failure(texto: (error as? ErrorSiri)?.mensaje ?? Textos.Errores.noLeido)
        }
    }
}

extension ManejadorVoz: @preconcurrency EliminarProductoVozIntentHandling {
    func provideProductoOptionsCollection(for intent: EliminarProductoVozIntent) async throws -> INObjectCollection<ProductoVoz> {
        try opciones()
    }

    func resolveProducto(for intent: EliminarProductoVozIntent) async -> ProductoVozResolutionResult {
        resolver(intent.producto)
    }

    // La definición pide confirmación: Siri pregunta antes de llamar a handle.
    func handle(intent: EliminarProductoVozIntent) async -> EliminarProductoVozIntentResponse {
        do {
            let (id, nombre) = try elegido(intent.producto)
            _ = try cambiarProducto(id, nombre: nombre, arranque: arranque) { inventario, producto throws(ErrorInventario) in
                try inventario.borrarProducto(producto.id)
                return producto
            }
            return .success(texto: Textos.Siri.eliminado(nombre))
        } catch {
            return .failure(texto: (error as? ErrorSiri)?.mensaje ?? Textos.Errores.noGuardadoMensaje)
        }
    }
}
