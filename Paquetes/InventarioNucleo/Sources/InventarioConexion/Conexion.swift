import Foundation
import InventarioNucleo

/// Todo lo que la app pide al servidor, ya con la sesión resuelta. Hay dos:
/// `ConexionServidor`, la de verdad, y `ConexionEnMemoria`, para las pruebas.
@MainActor
public protocol Conexion: AnyObject {
    func restaurar() async -> Restauracion
    /// Para la hoja de Safari del inicio de sesión con Google.
    func urlIniciarGoogle(estado: String) -> URL
    func entrar(conCodigoDeCanje codigo: String) async throws(ErrorConexion) -> Usuario
    func entrarConApple(identityToken: String, nonce: String) async throws(ErrorConexion) -> Usuario
    func cerrarSesion() async

    /// Los hogares de la cuenta, en el orden en que se unió a cada uno. Un
    /// hogar en el que ya no está da 404 en las demás: el servidor no dice si existe.
    func hogares() async throws(ErrorConexion) -> [Hogar]
    func crearHogar(nombre: String) async throws(ErrorConexion) -> Hogar
    func unirse(codigo: String) async throws(ErrorConexion) -> Hogar
    func invitar(hogar: String) async throws(ErrorConexion) -> Invitacion
    func salir(hogar: String) async throws(ErrorConexion)

    func cambiarNombre(_ nombre: String) async throws(ErrorConexion) -> Usuario
    func eliminarCuenta(codigoApple: String?) async throws(ErrorConexion)

    func avisos(hogar: String) async throws(ErrorConexion) -> Avisos
    func cambiarAvisos(_ avisos: Avisos, hogar: String) async throws(ErrorConexion) -> Avisos
    /// El token de APNs de este iPhone. Hay que quitarlo antes de cerrar sesión: después ya no hay con qué pedirlo.
    func registrarDispositivo(_ token: String, entorno: EntornoAvisos) async throws(ErrorConexion)
    func quitarDispositivo(_ token: String) async throws(ErrorConexion)

    func enviar(_ lote: Api.Lote, hogar: String) async throws(ErrorConexion) -> Api.RespuestaEnvio
    func novedades(desde revision: Int, hogar: String) async throws(ErrorConexion) -> Api.Novedades
}

@MainActor
public final class ConexionServidor: Conexion {
    private let cliente: ClienteApi
    private let sesion: Sesion

    public init(cliente: ClienteApi = ClienteApi(), credenciales: AlmacenCredenciales = CredencialesLlavero()) {
        self.cliente = cliente
        sesion = Sesion(cliente: cliente, credenciales: credenciales)
    }

    public func restaurar() async -> Restauracion { await sesion.restaurar() }

    public func urlIniciarGoogle(estado: String) -> URL {
        cliente.urlIniciar(proveedor: "google", estado: estado)
    }

    public func entrar(conCodigoDeCanje codigo: String) async throws(ErrorConexion) -> Usuario {
        try await sesion.entrar(conCodigoDeCanje: codigo)
    }

    public func entrarConApple(identityToken: String, nonce: String) async throws(ErrorConexion) -> Usuario {
        try await sesion.entrarConApple(identityToken: identityToken, nonce: nonce)
    }

    public func cerrarSesion() async { await sesion.cerrar() }

    public func hogares() async throws(ErrorConexion) -> [Hogar] {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in try await cliente.hogares(token: token) }
    }

    public func crearHogar(nombre: String) async throws(ErrorConexion) -> Hogar {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.crearHogar(nombre: nombre, token: token)
        }
    }

    public func unirse(codigo: String) async throws(ErrorConexion) -> Hogar {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.unirse(codigo: codigo, token: token)
        }
    }

    public func invitar(hogar: String) async throws(ErrorConexion) -> Invitacion {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.invitar(hogar: hogar, token: token)
        }
    }

    public func salir(hogar: String) async throws(ErrorConexion) {
        let cliente = self.cliente
        try await sesion.conToken { token throws(ErrorConexion) in try await cliente.salir(hogar: hogar, token: token) }
    }

    public func cambiarNombre(_ nombre: String) async throws(ErrorConexion) -> Usuario {
        let cliente = self.cliente
        let usuario = try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.cambiarNombre(nombre, token: token)
        }
        await sesion.actualizar(usuario)
        return usuario
    }

    public func eliminarCuenta(codigoApple: String?) async throws(ErrorConexion) {
        let cliente = self.cliente
        try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.eliminarCuenta(codigoApple: codigoApple, token: token)
        }
        // La cuenta ya no existe: no hay sesión que cerrar en el servidor.
        await sesion.olvidar()
    }

    public func avisos(hogar: String) async throws(ErrorConexion) -> Avisos {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.avisos(hogar: hogar, token: token)
        }
    }

    public func cambiarAvisos(_ avisos: Avisos, hogar: String) async throws(ErrorConexion) -> Avisos {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.cambiarAvisos(avisos, hogar: hogar, token: token)
        }
    }

    public func registrarDispositivo(_ dispositivo: String, entorno: EntornoAvisos) async throws(ErrorConexion) {
        let cliente = self.cliente
        try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.registrarDispositivo(dispositivo, entorno: entorno, token: token)
        }
    }

    public func quitarDispositivo(_ dispositivo: String) async throws(ErrorConexion) {
        let cliente = self.cliente
        try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.quitarDispositivo(dispositivo, token: token)
        }
    }

    public func enviar(_ lote: Api.Lote, hogar: String) async throws(ErrorConexion) -> Api.RespuestaEnvio {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.enviar(lote, hogar: hogar, token: token)
        }
    }

    public func novedades(desde revision: Int, hogar: String) async throws(ErrorConexion) -> Api.Novedades {
        let cliente = self.cliente
        return try await sesion.conToken { token throws(ErrorConexion) in
            try await cliente.novedades(desde: revision, hogar: hogar, token: token)
        }
    }
}
