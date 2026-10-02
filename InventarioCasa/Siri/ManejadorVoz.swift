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

    /// Qué preguntas se han hecho ya en cada acción en curso. La primera vez
    /// el valor llega vacío porque aún no se ha preguntado; si vuelve a llegar
    /// vacío es que Siri tomó la respuesta por una orden («despensa»,
    /// «fregona») y la perdió. Por identificador de la acción: está sin
    /// comprobar que Siri lo mantenga entre pregunta y pregunta (se anota).
    private static var yaPreguntado: Set<String> = []

    /// Las unidades que venían en la respuesta del producto («5 unidades de
    /// leche»), para no preguntarlas. Por identificador de la acción, que se
    /// mantiene entre preguntas (comprobado en el iPhone; el manejador, no).
    private static var unidadesDichas: [String: Int] = [:]

    private static func clave(_ intent: INIntent) -> String { intent.identifier ?? "sin identificador" }

    fileprivate func unidadesDichas(en intent: INIntent) -> Int? { Self.unidadesDichas[Self.clave(intent)] }

    /// Verdadero si esta pregunta ya se hizo en esta acción; si no, la apunta.
    fileprivate func segundaVez(_ intent: INIntent, _ parametro: String) -> Bool {
        let clave = "\(intent.identifier ?? "sin identificador")·\(parametro)"
        Self.anotar("Pregunta", "\(clave) en \(ObjectIdentifier(self).debugDescription)")
        return !Self.yaPreguntado.insert(clave).inserted
    }

    /// Al terminar una acción ya no hace falta recordar sus preguntas.
    fileprivate func olvidarPreguntas(_ intent: INIntent) {
        let prefijo = "\(Self.clave(intent))·"
        Self.yaPreguntado = Self.yaPreguntado.filter { !$0.hasPrefix(prefijo) }
        Self.unidadesDichas[Self.clave(intent)] = nil
    }

    // MARK: Producto

    /// Lo que se hace con el producto que se acaba de decir.
    fileprivate enum Busqueda {
        case falta
        case noEncontrado
        case uno(String)
        case varios([String])
    }

    /// Lo dicho se busca igual que en la app, sin tildes y en singular o
    /// plural. Si no hay ninguno, Siri lo dice en el momento y vuelve a
    /// preguntar; si encaja con varios, ofrece solo esos.
    /// Con `unidadesDe`, si lo dicho empieza por unidades («5 unidades de
    /// leche») y el resto es un producto, se apuntan para no preguntarlas.
    /// Si no encaja así, se busca la frase entera («Tres Ases» es un nombre).
    fileprivate func buscar(_ dicho: String?, unidadesDe intent: INIntent? = nil) -> Busqueda {
        guard let dicho, !Nombres.limpiar(dicho).isEmpty else { return .falta }
        guard let inventario = try? arranque.inventarioParaSiri() else { return .uno(dicho) }
        if let intent {
            let partes = PeticionVoz.separar(dicho)
            if let unidades = partes.unidades, !inventario.productosParaSiri(partes.producto).isEmpty {
                Self.unidadesDichas[Self.clave(intent)] = unidades
                Self.anotar("Unidades dichas", "\(unidades) en «\(dicho)»")
                return buscar(partes.producto)
            }
        }
        let encontrados = inventario.productosParaSiri(dicho)
        Self.anotar("Buscar producto", "«\(dicho)»: \(encontrados.count) encontrados")
        switch encontrados.count {
        case 0: return .noEncontrado
        case 1: return .uno(inventario.nombreParaSiri(encontrados[0]))
        default: return .varios(encontrados.map(inventario.nombreParaSiri))
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

    /// La pregunta por las unidades con el envase del producto ya elegido
    /// («¿Cuántas latas?»). Va en el parámetro oculto `pregunta`, que se
    /// resuelve entre el producto y las unidades: la definición solo admite
    /// textos fijos y la pregunta de las unidades es «${pregunta}».
    fileprivate func preguntaCantidad(_ dicho: String?, hay: Bool = false) -> INStringResolutionResult {
        let producto = (try? arranque.inventarioParaSiri())?.productosParaSiri(dicho ?? "").first
        let pregunta = Textos.Siri.preguntaCantidad(producto?.unidad ?? .unidad, hay: hay)
        Self.anotar("Pregunta por la cantidad", "«\(pregunta)» para «\(dicho ?? "")»")
        return .success(with: pregunta)
    }

    /// Suma (o resta) unidades, o las fija. Devuelve lo que contesta Siri.
    fileprivate func cambiarUnidades(_ dicho: String?, _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto) -> (ok: Bool, texto: String) {
        do {
            let (id, nombre) = try elegido(dicho)
            let (antes, despues) = try cambiarProducto(id, nombre: nombre, arranque: arranque, cambio)
            return (true, Textos.Siri.cambio(antes: antes, despues: despues))
        } catch {
            return Self.respuesta(error)
        }
    }

    /// Lo que se contesta cuando algo no se hace: si es una respuesta normal,
    /// va como éxito (ver `ErrorSiri.esRespuesta`).
    static func respuesta(_ error: any Error, siNoSeSabe: String = Textos.Errores.noGuardadoMensaje) -> (ok: Bool, texto: String) {
        guard let error = error as? ErrorSiri else { return (false, siNoSeSabe) }
        return (error.esRespuesta, error.mensaje)
    }

    /// Para seguir en el registro del iPhone qué pregunta Siri y qué se contesta.
    static func anotar(_ accion: String, _ detalle: String) {
        registroSiri.notice("\(accion, privacy: .public): \(detalle, privacy: .public)")
    }
}

// MARK: Crear producto

extension ManejadorVoz: @preconcurrency CrearProductoVozIntentHandling {
    func resolveNombre(for intent: CrearProductoVozIntent) async -> CrearProductoVozNombreResolutionResult {
        Self.anotar("Crear", "nombre «\(intent.nombre ?? "")»")
        guard let nombre = intent.nombre, !Nombres.limpiar(nombre).isEmpty else {
            return segundaVez(intent, "nombre") ? .unsupported(forReason: .noEntendido) : .needsValue()
        }
        return .success(with: nombre)
    }

    /// Se comprueba aquí y no al crear: así Siri lo dice en el momento y
    /// vuelve a preguntar, en lugar de después de pedir las unidades.
    func resolveCategoria(for intent: CrearProductoVozIntent) async -> CrearProductoVozCategoriaResolutionResult {
        Self.anotar("Crear", "categoría «\(intent.categoria ?? "")»")
        guard let inventario = try? arranque.inventarioParaSiri() else {
            return intent.categoria.map { .success(with: $0) } ?? .needsValue()
        }
        guard let dicha = intent.categoria, !Nombres.limpiar(dicha).isEmpty else {
            // Respuesta perdida: se ofrecen las categorías que hay.
            let nombres = inventario.categorias.map(\.nombre)
            return segundaVez(intent, "categoria") && !nombres.isEmpty ? .disambiguation(with: nombres) : .needsValue()
        }
        let encontradas = inventario.buscarCategorias(dicha)
        guard let categoria = encontradas.first else { return .unsupported(forReason: .noEncontrada) }
        guard encontradas.count == 1 else { return .unsupported(forReason: .varias) }
        let nombre = Nombres.clave(intent.nombre ?? "")
        if inventario.productos(en: categoria.id).contains(where: { Nombres.clave($0.nombre) == nombre }) {
            return .unsupported(forReason: .repetido)
        }
        return .success(with: categoria.nombre)
    }

    func resolveUnidades(for intent: CrearProductoVozIntent) async -> CrearProductoVozUnidadesResolutionResult {
        Self.anotar("CrearProducto", "unidades \(intent.unidades?.intValue ?? -1)")
        guard let unidades = intent.unidades?.intValue else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: CrearProductoVozIntent) async -> CrearProductoVozIntentResponse {
        Self.anotar("CrearProducto", "atender")
        olvidarPreguntas(intent)
        do {
            let texto = try crearProductoPorVoz(
                nombre: intent.nombre ?? "",
                categoria: intent.categoria ?? "",
                unidades: intent.unidades?.intValue ?? 0,
                arranque: arranque
            )
            Self.anotar("Crear", "hecho: \(texto)")
            return .success(texto: texto)
        } catch {
            let (ok, texto) = Self.respuesta(error)
            Self.anotar("Crear", "no hecho: \(texto)")
            return ok ? .success(texto: texto) : .failure(texto: texto)
        }
    }
}

// MARK: Añadir, quitar y cambiar unidades

extension ManejadorVoz: @preconcurrency AnadirUnidadesVozIntentHandling {
    func resolveProducto(for intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozProductoResolutionResult {
        switch buscar(intent.producto, unidadesDe: intent) {
        case .falta: .needsValue()
        case .noEncontrado: .unsupported(forReason: .noEncontrado)
        case .uno(let nombre): .success(with: nombre)
        case .varios(let nombres): .disambiguation(with: nombres)
        }
    }

    func resolvePregunta(for intent: AnadirUnidadesVozIntent) async -> INStringResolutionResult {
        preguntaCantidad(intent.producto)
    }

    func resolveUnidades(for intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozUnidadesResolutionResult {
        Self.anotar("AnadirUnidades", "unidades \(intent.unidades?.intValue ?? -1)")
        guard let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: AnadirUnidadesVozIntent) async -> AnadirUnidadesVozIntentResponse {
        Self.anotar("AnadirUnidades", "atender")
        let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) ?? 1
        olvidarPreguntas(intent)
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: unidades)
        }
        Self.anotar("AnadirUnidades", texto)
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

extension ManejadorVoz: @preconcurrency QuitarUnidadesVozIntentHandling {
    func resolveProducto(for intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozProductoResolutionResult {
        switch buscar(intent.producto, unidadesDe: intent) {
        case .falta: .needsValue()
        case .noEncontrado: .unsupported(forReason: .noEncontrado)
        case .uno(let nombre): .success(with: nombre)
        case .varios(let nombres): .disambiguation(with: nombres)
        }
    }

    func resolvePregunta(for intent: QuitarUnidadesVozIntent) async -> INStringResolutionResult {
        preguntaCantidad(intent.producto)
    }

    func resolveUnidades(for intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozUnidadesResolutionResult {
        Self.anotar("QuitarUnidades", "unidades \(intent.unidades?.intValue ?? -1)")
        guard let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: QuitarUnidadesVozIntent) async -> QuitarUnidadesVozIntentResponse {
        Self.anotar("QuitarUnidades", "atender")
        let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) ?? 1
        olvidarPreguntas(intent)
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.ajustarCantidad(producto.id, en: -unidades)
        }
        Self.anotar("QuitarUnidades", texto)
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

extension ManejadorVoz: @preconcurrency CambiarCantidadVozIntentHandling {
    func resolveProducto(for intent: CambiarCantidadVozIntent) async -> CambiarCantidadVozProductoResolutionResult {
        switch buscar(intent.producto, unidadesDe: intent) {
        case .falta: .needsValue()
        case .noEncontrado: .unsupported(forReason: .noEncontrado)
        case .uno(let nombre): .success(with: nombre)
        case .varios(let nombres): .disambiguation(with: nombres)
        }
    }

    func resolvePregunta(for intent: CambiarCantidadVozIntent) async -> INStringResolutionResult {
        preguntaCantidad(intent.producto, hay: true)
    }

    func resolveUnidades(for intent: CambiarCantidadVozIntent) async -> CambiarCantidadVozUnidadesResolutionResult {
        Self.anotar("CambiarCantidad", "unidades \(intent.unidades?.intValue ?? -1)")
        guard let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) else { return .needsValue() }
        return .success(with: unidades)
    }

    func handle(intent: CambiarCantidadVozIntent) async -> CambiarCantidadVozIntentResponse {
        Self.anotar("CambiarCantidad", "atender")
        let unidades = intent.unidades?.intValue ?? unidadesDichas(en: intent) ?? 0
        olvidarPreguntas(intent)
        let (ok, texto) = cambiarUnidades(intent.producto) { inventario, producto throws(ErrorInventario) in
            try inventario.editarProducto(
                producto.id,
                nombre: producto.nombre,
                unidad: producto.unidad,
                cantidad: unidades,
                umbralCompra: producto.umbralCompra,
                autoListaCompra: producto.autoListaCompra
            )
        }
        Self.anotar("CambiarCantidad", texto)
        return ok ? .success(texto: texto) : .failure(texto: texto)
    }
}

// MARK: Consultar y eliminar

extension ManejadorVoz: @preconcurrency ConsultarProductoVozIntentHandling {
    func resolveProducto(for intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozProductoResolutionResult {
        switch buscar(intent.producto) {
        case .falta: .needsValue()
        case .noEncontrado: .unsupported(forReason: .noEncontrado)
        case .uno(let nombre): .success(with: nombre)
        case .varios(let nombres): .disambiguation(with: nombres)
        }
    }

    func handle(intent: ConsultarProductoVozIntent) async -> ConsultarProductoVozIntentResponse {
        Self.anotar("ConsultarProducto", "atender")
        do {
            let (id, nombre) = try elegido(intent.producto)
            guard let producto = try arranque.inventarioParaSiri().producto(id) else {
                throw ErrorSiri.noEncontrado(nombre, arranque: arranque)
            }
            return .success(texto: Textos.Siri.resultado(producto))
        } catch {
            let (ok, texto) = Self.respuesta(error, siNoSeSabe: Textos.Errores.noLeido)
            Self.anotar("Consultar", texto)
            return ok ? .success(texto: texto) : .failure(texto: texto)
        }
    }
}

extension ManejadorVoz: @preconcurrency EliminarProductoVozIntentHandling {
    func resolveProducto(for intent: EliminarProductoVozIntent) async -> EliminarProductoVozProductoResolutionResult {
        switch buscar(intent.producto) {
        case .falta: .needsValue()
        case .noEncontrado: .unsupported(forReason: .noEncontrado)
        case .uno(let nombre): .success(with: nombre)
        case .varios(let nombres): .disambiguation(with: nombres)
        }
    }

    // La definición pide confirmación: Siri pregunta antes de llamar a handle.
    func handle(intent: EliminarProductoVozIntent) async -> EliminarProductoVozIntentResponse {
        Self.anotar("EliminarProducto", "atender")
        do {
            let (id, nombre) = try elegido(intent.producto)
            _ = try cambiarProducto(id, nombre: nombre, arranque: arranque) { inventario, producto throws(ErrorInventario) in
                try inventario.borrarProducto(producto.id)
                return producto
            }
            return .success(texto: Textos.Siri.eliminado(nombre))
        } catch {
            let (ok, texto) = Self.respuesta(error)
            Self.anotar("Eliminar", texto)
            return ok ? .success(texto: texto) : .failure(texto: texto)
        }
    }
}
