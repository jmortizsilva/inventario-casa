import Foundation

/// Las respuestas de cuenta y hogar del contrato (`servidor/docs/CONTRATO-API.md`).
/// Las de sincronización están en `Api`, en el núcleo.

public struct Usuario: Codable, Equatable, Sendable {
    public let id: Int
    public let email: String
    /// El que dio el proveedor o el que se puso con `PUT /cuenta/nombre`.
    /// Con Apple es nil hasta que se pone.
    public let nombre: String?
    public let proveedor: String

    public init(id: Int, email: String, nombre: String?, proveedor: String) {
        self.id = id
        self.email = email
        self.nombre = nombre
        self.proveedor = proveedor
    }

    public var esDeApple: Bool { proveedor == "apple" }
}

public struct RespuestaSesion: Codable, Sendable {
    public let tokenAcceso: String
    public let expiraEn: Int64
    public let tokenRefresco: String
    public let usuario: Usuario?
}

public struct Miembro: Codable, Equatable, Sendable {
    public let id: Int
    public let nombre: String?
    public let email: String

    public init(id: Int, nombre: String?, email: String) {
        self.id = id
        self.nombre = nombre
        self.email = email
    }
}

public struct Hogar: Codable, Equatable, Sendable {
    public let id: String
    public let nombre: String
    public let miembros: [Miembro]
    public let revision: Int

    public init(id: String, nombre: String, miembros: [Miembro], revision: Int) {
        self.id = id
        self.nombre = nombre
        self.miembros = miembros
        self.revision = revision
    }
}

public struct Invitacion: Codable, Equatable, Sendable {
    public let codigo: String
    public let caducaEn: Int64

    public init(codigo: String, caducaEn: Int64) {
        self.codigo = codigo
        self.caducaEn = caducaEn
    }
}
