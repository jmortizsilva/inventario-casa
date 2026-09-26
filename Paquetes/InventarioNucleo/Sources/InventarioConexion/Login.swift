import CryptoKit
import Foundation
import InventarioNucleo

/// Iniciar sesión, según el contrato. Copiado de Guardar Enlaces, que ya lo
/// usa en el iPhone.
///
/// Con Google la app no habla con Google: abre `/auth/iniciar` del servidor
/// en la hoja de Safari, el servidor hace el intercambio y devuelve la hoja a
/// `inventariocasa://auth-callback?codigo=…`. Ese código dura un minuto y se
/// cambia por la sesión con `/auth/canjear`.
public enum Login {
    public static let esquema = "inventariocasa"

    public enum Resultado: Equatable, Sendable {
        case exito(codigoDeCanje: String)
        /// Cerró la hoja. Lo ha decidido la persona: no se dice nada.
        case cancelado
        case error(Textos.Causa)
    }

    /// Cadena de un solo uso que ata la vuelta a esta petición. 16 bytes en hexadecimal.
    public static func generarEstado(aleatorio: (Int) -> [UInt8] = bytesAleatorios) -> String {
        aleatorio(16).map { String(format: "%02x", $0) }.joined()
    }

    /// Se leen solo los parámetros: el esquema es de la app y lo único que
    /// importa es qué trae.
    public static func leerCallback(_ url: URL) -> Resultado {
        let parametros = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let porNombre = Dictionary(parametros.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        if let codigo = porNombre["codigo"], !codigo.isEmpty {
            return .exito(codigoDeCanje: codigo)
        }
        return .error(causa(delError: porNombre["error"] ?? ""))
    }

    /// Los motivos que manda el servidor en la vuelta o en `/auth/apple-nativo`.
    public static func causa(delError error: String) -> Textos.Causa {
        switch error {
        case "sin_email": .sinCorreo
        case "fallo_intercambio": .proveedorRechaza
        default: .servidorNoResponde
        }
    }

    /// A Apple se le manda solo el `resumen`, y al servidor el valor `enClaro`:
    /// el servidor comprueba que uno es el resumen del otro, y así el token no
    /// vale para otra petición.
    public struct NonceDeApple: Equatable, Sendable {
        public let enClaro: String
        public let resumen: String
    }

    public static func nonceParaApple(aleatorio: (Int) -> [UInt8] = bytesAleatorios) -> NonceDeApple {
        let enClaro = aleatorio(32).map { String(format: "%02x", $0) }.joined()
        let resumen = SHA256.hash(data: Data(enClaro.utf8)).map { String(format: "%02x", $0) }.joined()
        return NonceDeApple(enClaro: enClaro, resumen: resumen)
    }

    public static func bytesAleatorios(_ cuantos: Int) -> [UInt8] {
        var generador = SystemRandomNumberGenerator()
        return (0..<cuantos).map { _ in UInt8.random(in: 0...255, using: &generador) }
    }
}
