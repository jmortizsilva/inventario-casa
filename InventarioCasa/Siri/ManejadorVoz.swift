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

    /// Lo dicho se busca igual que en la app, sin tildes y en singular o
    /// plural. Si encaja con varios, Siri ofrece solo esos; sin ninguno se da
    /// por bueno y, al atenderlo, contesta «No encuentro…», que dice más que
    /// volver a preguntar.
    fileprivate func resolver(_ dicho: String?) -> INStringResolutionResult {
        guard let dicho, !Nombres.limpiar(dicho).isEmpty else { return .needsValue() }
        guard let inventario = try? arranque.inventarioParaSiri() else { return .success(with: dicho) }
        let encontrados = inventario.productosParaSiri(dicho)
        registroSiri.info("Buscar producto «\(dicho, privacy: .public)»: \(encontrados.count) encontrados")
        switch encontrados.count {
        case 0: return .success(with: dicho)
        case 1: return .success(with: inventario.nombreParaSiri(encontrados[0]))
        default: return .disambiguation(with: encontrados.map(inventario.nombreParaSiri))
        }
    }

    /// El producto elegido, o el error con lo que dice Siri.
    fileprivate func elegido(_ dicho: String?) throws -> (id: UUID, nombre: String) {
        let nombre = dicho ?? ""
        let inventario = try arranque.inventarioParaSiri()
        guard let producto = inventario.productosParaSiri(nombre).first else {
            throw ErrorSiri.noEncontrado(nombre, arranque: arranque)
        }
        return (producto.id, producto.nombre)
    }

    /// Suma (o resta) unidades, o las fija. Devuelve lo que contesta Siri.
    fileprivate func cambiarUnidades(_ dicho: String?, _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto) -> (ok: Bool, texto: String) {
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
    func resolveProducto(for intent: AnadirUnidadesVozIntent) async -> INStringResolutionResult {
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
    func resolveProducto(for intent: QuitarUnidadesVozIntent) async -> INStringResolutionResult {
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
    func resolveProducto(for intent: CambiarCantidadVozIntent) async -> INStringResolutionResult {
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
    func resolveProducto(for intent: ConsultarProductoVozIntent) async -> INStringResolutionResult {
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
    func resolveProducto(for intent: EliminarProductoVozIntent) async -> INStringResolutionResult {
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
