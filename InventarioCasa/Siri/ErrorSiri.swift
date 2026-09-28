import AppIntents
import InventarioAlmacen
import InventarioNucleo

/// Lo que Siri dice cuando la acción no se puede hacer.
struct ErrorSiri: Error, CustomLocalizedStringResourceConvertible {
    let mensaje: String

    var localizedStringResource: LocalizedStringResource { "\(mensaje)" }

    /// El producto ya no está: otra persona lo eliminó mientras Siri preguntaba.
    @MainActor
    static func noEncontrado(_ nombre: String, arranque: Arranque) -> ErrorSiri {
        ErrorSiri(mensaje: Textos.Siri.noEncontrado(nombre, en: arranque.cuenta?.nombreDelHogar))
    }

    /// Los errores de nombre los traduce quien crea, que sabe en qué categoría.
    static let noGuardado = ErrorSiri(mensaje: Textos.Errores.noGuardadoMensaje)
}

extension Arranque {
    /// El inventario del hogar abierto. Abre el almacén si Siri ha arrancado
    /// la app en segundo plano.
    func inventarioParaSiri() throws -> Inventario {
        guard let cuenta = abrir() else { throw ErrorSiri(mensaje: Textos.Errores.noLeido) }
        return cuenta.inventario
    }
}
