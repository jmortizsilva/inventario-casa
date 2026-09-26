import Foundation
import Security

/// Lo que se guarda de la sesión entre dos aperturas de la app: el token de
/// refresco y quién es. El usuario se guarda para poder enseñarlo sin
/// conexión; el token de acceso no se guarda, dura poco.
public struct SesionGuardada: Codable, Equatable, Sendable {
    public let tokenRefresco: String
    public let usuario: Usuario?
}

public protocol AlmacenCredenciales: Sendable {
    func leer() throws -> SesionGuardada?
    func guardar(_ sesion: SesionGuardada) throws
    func borrar() throws
}

/// En el llavero de iOS, nunca en un fichero ni en las preferencias.
public struct CredencialesLlavero: AlmacenCredenciales {
    private let servicio: String

    public init(servicio: String = "inventario-casa") {
        self.servicio = servicio
    }

    public struct Fallo: Error {
        public let estado: OSStatus
    }

    private var consultaBase: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: "sesion",
        ]
    }

    public func leer() throws -> SesionGuardada? {
        var consulta = consultaBase
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        consulta[kSecReturnData as String] = true
        var resultado: CFTypeRef?
        let estado = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        if estado == errSecItemNotFound { return nil }
        guard estado == errSecSuccess, let datos = resultado as? Data else { throw Fallo(estado: estado) }
        return try JSONDecoder().decode(SesionGuardada.self, from: datos)
    }

    public func guardar(_ sesion: SesionGuardada) throws {
        // Después del primer desbloqueo y solo en este iPhone: la
        // sincronización puede arrancar al volver a la app sin haber
        // desbloqueado otra vez, y el token no viaja a copias de seguridad.
        let atributos: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(sesion),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let actualizado = SecItemUpdate(consultaBase as CFDictionary, atributos as CFDictionary)
        if actualizado == errSecSuccess { return }
        guard actualizado == errSecItemNotFound else { throw Fallo(estado: actualizado) }
        let alta = SecItemAdd(consultaBase.merging(atributos) { _, nuevo in nuevo } as CFDictionary, nil)
        guard alta == errSecSuccess else { throw Fallo(estado: alta) }
    }

    public func borrar() throws {
        let estado = SecItemDelete(consultaBase as CFDictionary)
        guard estado == errSecSuccess || estado == errSecItemNotFound else { throw Fallo(estado: estado) }
    }
}

/// Para pruebas.
public final class CredencialesEnMemoria: AlmacenCredenciales, @unchecked Sendable {
    private let cerrojo = NSLock()
    private var guardada: SesionGuardada?

    public init(_ inicial: SesionGuardada? = nil) { guardada = inicial }

    public func leer() throws -> SesionGuardada? { cerrojo.withLock { guardada } }
    public func guardar(_ sesion: SesionGuardada) throws { cerrojo.withLock { guardada = sesion } }
    public func borrar() throws { cerrojo.withLock { guardada = nil } }
}
