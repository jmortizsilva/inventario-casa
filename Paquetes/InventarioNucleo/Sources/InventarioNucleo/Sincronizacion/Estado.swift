import Foundation

/// A qué hogar está unido este iPhone y hasta qué revisión ha bajado.
/// Sin hogar no se anota nada en la cola: no habría adónde enviarlo.
public struct EstadoSincronizacion: Codable, Equatable, Sendable {
    public var hogarId: String?
    /// La última revisión bajada con `GET /sincronizar`. Solo la mueven las
    /// bajadas: la respuesta a un envío trae la revisión del hogar entero, y
    /// guardarla saltaría los cambios de otras personas que aún no se han bajado.
    public var revision: Int

    public init(hogarId: String? = nil, revision: Int = 0) {
        self.hogarId = hogarId
        self.revision = revision
    }

    public static let sinHogar = EstadoSincronizacion()
}
