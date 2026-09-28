import Foundation
import Testing
import InventarioNucleo
@testable import InventarioConexion

/// Sustituye a la red: cada petición la contesta `responder`.
final class ProtocoloFalso: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: (URLRequest) -> (Int, Data)? = { _ in nil }
    nonisolated(unsafe) static var peticiones: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var peticion = request
        // URLSession pasa el cuerpo como flujo: se lee para poder comprobarlo.
        if peticion.httpBody == nil, let flujo = peticion.httpBodyStream {
            flujo.open()
            var datos = Data()
            var trozo = [UInt8](repeating: 0, count: 4096)
            while flujo.hasBytesAvailable {
                let leidos = flujo.read(&trozo, maxLength: trozo.count)
                if leidos <= 0 { break }
                datos.append(trozo, count: leidos)
            }
            flujo.close()
            peticion.httpBody = datos
        }
        Self.peticiones.append(peticion)
        guard let (codigo, datos) = Self.responder(peticion) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let respuesta = HTTPURLResponse(url: request.url!, statusCode: codigo, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: respuesta, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: datos)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func sesionHttp() -> URLSession {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.protocolClasses = [ProtocoloFalso.self]
        return URLSession(configuration: configuracion)
    }
}

private let usuarioJson = #"{"id":1,"email":"ana@ejemplo.com","nombre":"Ana","proveedor":"google"}"#

private func sesionJson(_ acceso: String, _ refresco: String) -> Data {
    Data(#"{"tokenAcceso":"\#(acceso)","expiraEn":0,"tokenRefresco":"\#(refresco)","usuario":\#(usuarioJson)}"#.utf8)
}

private let ana = Usuario(id: 1, email: "ana@ejemplo.com", nombre: "Ana", proveedor: "google")

/// En serie: el protocolo falso es uno para todo el proceso.
@MainActor
@Suite(.serialized) struct ConexionServidorPruebas {
    init() {
        ProtocoloFalso.peticiones = []
        ProtocoloFalso.responder = { _ in nil }
    }

    private func conexion(_ credenciales: CredencialesEnMemoria) -> ConexionServidor {
        ConexionServidor(
            cliente: ClienteApi(base: URL(string: "https://servidor.prueba")!, http: ProtocoloFalso.sesionHttp()),
            credenciales: credenciales
        )
    }

    @Test func eliminarLaCuentaMandaSiempreUnCuerpo() async throws {
        ProtocoloFalso.responder = { peticion in
            switch peticion.url?.path {
            case "/auth/renovar": (200, sesionJson("acceso", "refresco-2"))
            case "/cuenta": (200, Data(#"{"ok":true}"#.utf8))
            default: nil
            }
        }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: ana))
        try await conexion(credenciales).eliminarCuenta(codigoApple: nil)

        let borrado = try #require(ProtocoloFalso.peticiones.last)
        #expect(borrado.httpMethod == "DELETE")
        #expect(borrado.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(borrado.httpBody == Data("{}".utf8))
        #expect(borrado.value(forHTTPHeaderField: "Authorization") == "Bearer acceso")
        // La cuenta ya no existe: no queda sesión guardada.
        #expect(try credenciales.leer() == nil)
    }

    @Test func abrirSinConexionNoCierraLaSesion() async throws {
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: ana))
        let restauracion = await conexion(credenciales).restaurar()
        #expect(restauracion == .sinConexion(ana))
        #expect(try credenciales.leer()?.tokenRefresco == "refresco-1")
    }

    @Test func unTokenQueYaNoValeCierraLaSesion() async throws {
        ProtocoloFalso.responder = { _ in (401, Data(#"{"error":"token de refresco invalido o caducado"}"#.utf8)) }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "revocado", usuario: ana))
        #expect(await conexion(credenciales).restaurar() == .sinSesion)
        #expect(try credenciales.leer() == nil)
    }

    @Test func alRenovarSeGuardaElTokenNuevo() async throws {
        ProtocoloFalso.responder = { _ in (200, sesionJson("acceso", "refresco-2")) }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: nil))
        #expect(await conexion(credenciales).restaurar() == .conSesion(ana))
        #expect(try credenciales.leer() == SesionGuardada(tokenRefresco: "refresco-2", usuario: ana))
    }

    @Test func dosPeticionesALaVezRenuevanUnaSolaVez() async throws {
        ProtocoloFalso.responder = { peticion in
            switch peticion.url?.path {
            case "/auth/renovar": (200, sesionJson("acceso", "refresco-2"))
            case "/hogares": (200, Data(#"{"hogares":[]}"#.utf8))
            default: nil
            }
        }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: ana))
        let conexion = conexion(credenciales)
        async let uno = conexion.hogares()
        async let dos = conexion.hogares()
        _ = try await (uno, dos)

        let renovaciones = ProtocoloFalso.peticiones.filter { $0.url?.path == "/auth/renovar" }
        #expect(renovaciones.count == 1)
    }

    @Test func losErroresDelServidorLlegan() async throws {
        ProtocoloFalso.responder = { peticion in
            switch peticion.url?.path {
            case "/auth/renovar": (200, sesionJson("acceso", "refresco-2"))
            case "/hogares/unirse": (404, Data(#"{"error":"código no válido"}"#.utf8))
            default: nil
            }
        }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: ana))
        await #expect(throws: ErrorConexion.servidor(codigo: 404, error: "código no válido")) {
            _ = try await conexion(credenciales).unirse(codigo: "MALO2222")
        }
    }

    @Test func pideLasNovedadesDesdeLaRevision() async throws {
        ProtocoloFalso.responder = { peticion in
            switch peticion.url?.path {
            case "/auth/renovar": (200, sesionJson("acceso", "refresco-2"))
            case "/hogares/h1/sincronizar":
                (200, Data(#"{"categorias":[],"productos":[],"revision":9,"masDisponible":false}"#.utf8))
            default: nil
            }
        }
        let credenciales = CredencialesEnMemoria(SesionGuardada(tokenRefresco: "refresco-1", usuario: ana))
        let novedades = try await conexion(credenciales).novedades(desde: 7, hogar: "h1")

        #expect(novedades.revision == 9)
        let peticion = try #require(ProtocoloFalso.peticiones.last)
        #expect(peticion.httpMethod == "GET")
        #expect(peticion.url?.query == "desde=7&limite=500")
        #expect(peticion.httpBody == nil || peticion.httpBody?.isEmpty == true)
    }
}

@Suite struct LoginPruebas {
    @Test func leeLaVuelta() {
        #expect(Login.leerCallback(URL(string: "inventariocasa://auth-callback?codigo=abc")!) == .exito(codigoDeCanje: "abc"))
        #expect(Login.leerCallback(URL(string: "inventariocasa://auth-callback?error=sin_email")!) == .error(.sinCorreo))
        #expect(
            Login.leerCallback(URL(string: "inventariocasa://auth-callback?error=fallo_intercambio")!)
                == .error(.proveedorRechaza)
        )
        #expect(Login.leerCallback(URL(string: "inventariocasa://auth-callback")!) == .error(.servidorNoResponde))
    }

    @Test func estadoYNonce() {
        #expect(Login.generarEstado { Array(repeating: 0xab, count: $0) } == String(repeating: "ab", count: 16))
        let nonce = Login.nonceParaApple { Array(repeating: 0, count: $0) }
        #expect(nonce.enClaro == String(repeating: "00", count: 32))
        // sha256 de 64 ceros en texto, calculado aparte con `shasum -a 256`.
        #expect(nonce.resumen == "60e05bd1b195af2f94112fa7197a5c88289058840ce7c6df9693756bc6250f55")
    }

    @Test func laDireccionDeGoogleLlevaElEsquema() {
        let url = ClienteApi(base: URL(string: "https://servidor.prueba")!).urlIniciar(proveedor: "google", estado: "e1")
        let partes = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(partes.path == "/auth/iniciar")
        #expect(partes.queryItems?.first { $0.name == "esquema" }?.value == "inventariocasa")
        #expect(partes.queryItems?.first { $0.name == "modo" }?.value == "deeplink")
    }
}
