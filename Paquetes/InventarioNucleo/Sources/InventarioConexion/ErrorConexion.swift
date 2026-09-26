import Foundation
import InventarioNucleo

/// Un fallo hablando con el servidor. Qué decir lo decide la pantalla con
/// `causa`; los casos concretos de cada ruta (código que no sirve, demasiados
/// intentos) se miran por `codigo` y `error`.
public enum ErrorConexion: Error, Equatable, Sendable {
    /// No se llegó a hablar con nadie.
    case sinConexion
    /// Ni el token de acceso ni el de refresco sirven: hay que volver a iniciar sesión.
    case sesionCaducada
    /// El servidor contestó con un error. `error` es el campo del cuerpo, si lo había.
    case servidor(codigo: Int, error: String?)
    case respuestaIlegible

    public var codigo: Int? {
        if case .servidor(let codigo, _) = self { return codigo }
        return nil
    }

    public var error: String? {
        if case .servidor(_, let error) = self { return error }
        return nil
    }

    public var causa: Textos.Causa {
        self == .sinConexion ? .sinConexion : .servidorNoResponde
    }
}
