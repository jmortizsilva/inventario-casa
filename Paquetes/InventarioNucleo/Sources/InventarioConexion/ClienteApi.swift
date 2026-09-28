import Foundation
import InventarioNucleo

/// Cliente HTTP del servidor. No decide nada: traduce llamadas a peticiones y
/// respuestas a tipos. Quién renueva la sesión y cuándo es cosa de `Sesion`.
public struct ClienteApi: Sendable {
    public static let urlPorDefecto = URL(string: "https://inventario.jmortiz.es")!

    private let base: URL
    private let http: URLSession

    public init(base: URL = urlPorDefecto, http: URLSession = .conPlazo) {
        self.base = base
        self.http = http
    }

    // MARK: Autenticación

    /// Se abre en la hoja de Safari, no se pide desde aquí.
    public func urlIniciar(proveedor: String, estado: String) -> URL {
        var partes = URLComponents(url: base.appending(path: "auth/iniciar"), resolvingAgainstBaseURL: false)!
        partes.queryItems = [
            URLQueryItem(name: "proveedor", value: proveedor),
            URLQueryItem(name: "modo", value: "deeplink"),
            URLQueryItem(name: "estado", value: estado),
            URLQueryItem(name: "esquema", value: Login.esquema),
        ]
        return partes.url!
    }

    public func canjear(codigo: String) async throws(ErrorConexion) -> RespuestaSesion {
        try await pedir("POST", "auth/canjear", cuerpo: ["codigoCanje": codigo])
    }

    public func entrarConApple(identityToken: String, nonce: String) async throws(ErrorConexion) -> RespuestaSesion {
        try await pedir("POST", "auth/apple-nativo", cuerpo: ["identityToken": identityToken, "nonce": nonce])
    }

    public func renovar(tokenRefresco: String) async throws(ErrorConexion) -> RespuestaSesion {
        try await pedir("POST", "auth/renovar", cuerpo: ["tokenRefresco": tokenRefresco])
    }

    public func cerrarSesion(tokenRefresco: String) async throws(ErrorConexion) {
        let _: Vacia = try await pedir("POST", "auth/logout", cuerpo: ["tokenRefresco": tokenRefresco])
    }

    // MARK: Hogares
    //
    // Las rutas de varios hogares (/hogares…). Las de uno solo (/hogar…) son de las
    // compilaciones anteriores y esta ya no las usa.

    public func hogares(token: String) async throws(ErrorConexion) -> [Hogar] {
        let respuesta: ConHogares = try await pedir("GET", "hogares", token: token)
        return respuesta.hogares
    }

    public func crearHogar(nombre: String, token: String) async throws(ErrorConexion) -> Hogar {
        let respuesta: ConHogar = try await pedir("POST", "hogares", cuerpo: ["nombre": nombre], token: token)
        guard let hogar = respuesta.hogar else { throw .respuestaIlegible }
        return hogar
    }

    public func unirse(codigo: String, token: String) async throws(ErrorConexion) -> Hogar {
        let respuesta: ConHogar = try await pedir("POST", "hogares/unirse", cuerpo: ["codigo": codigo], token: token)
        guard let hogar = respuesta.hogar else { throw .respuestaIlegible }
        return hogar
    }

    public func invitar(hogar: String, token: String) async throws(ErrorConexion) -> Invitacion {
        try await pedir("POST", "hogares/\(hogar)/invitaciones", cuerpo: [String: String](), token: token)
    }

    public func salir(hogar: String, token: String) async throws(ErrorConexion) {
        let _: Vacia = try await pedir("POST", "hogares/\(hogar)/salir", cuerpo: [String: String](), token: token)
    }

    // MARK: Cuenta

    public func cambiarNombre(_ nombre: String, token: String) async throws(ErrorConexion) -> Usuario {
        let respuesta: ConUsuario = try await pedir("PUT", "cuenta/nombre", cuerpo: ["nombre": nombre], token: token)
        return respuesta.usuario
    }

    /// Siempre con cuerpo, aunque sea `{}`: con `Content-Type: application/json`
    /// y el cuerpo vacío, Fastify responde 400 antes de llegar a la ruta.
    public func eliminarCuenta(codigoApple: String?, token: String) async throws(ErrorConexion) {
        var cuerpo: [String: String] = [:]
        if let codigoApple { cuerpo["codigoApple"] = codigoApple }
        let _: Vacia = try await pedir("DELETE", "cuenta", cuerpo: cuerpo, token: token)
    }

    // MARK: Notificaciones

    public func avisos(hogar: String, token: String) async throws(ErrorConexion) -> Avisos {
        try await pedir("GET", "hogares/\(hogar)/avisos", token: token)
    }

    public func cambiarAvisos(_ avisos: Avisos, hogar: String, token: String) async throws(ErrorConexion) -> Avisos {
        try await pedir("PUT", "hogares/\(hogar)/avisos", cuerpo: avisos, token: token)
    }

    public func registrarDispositivo(_ dispositivo: String, entorno: EntornoAvisos, token: String) async throws(ErrorConexion) {
        let _: Vacia = try await pedir(
            "PUT", "dispositivos",
            cuerpo: ["token": dispositivo, "plataforma": "ios", "entorno": entorno.rawValue],
            token: token
        )
    }

    public func quitarDispositivo(_ dispositivo: String, token: String) async throws(ErrorConexion) {
        let _: Vacia = try await pedir("DELETE", "dispositivos/\(dispositivo)", cuerpo: [String: String](), token: token)
    }

    // MARK: Sincronización

    public func enviar(_ lote: Api.Lote, hogar: String, token: String) async throws(ErrorConexion) -> Api.RespuestaEnvio {
        try await pedir("POST", "hogares/\(hogar)/sincronizar", cuerpo: lote, token: token)
    }

    public func novedades(
        desde: Int, limite: Int = 500, hogar: String, token: String
    ) async throws(ErrorConexion) -> Api.Novedades {
        try await pedir(
            "GET", "hogares/\(hogar)/sincronizar", consulta: ["desde": "\(desde)", "limite": "\(limite)"], token: token
        )
    }

    // MARK: Fontanería

    private struct Vacia: Decodable {}
    private struct ConHogar: Decodable { let hogar: Hogar? }
    private struct ConHogares: Decodable { let hogares: [Hogar] }
    private struct ConUsuario: Decodable { let usuario: Usuario }
    private struct SinCuerpo: Encodable {}
    private struct CuerpoError: Decodable { let error: String? }

    private func pedir<T: Decodable>(
        _ metodo: String, _ ruta: String, consulta: [String: String] = [:], token: String? = nil
    ) async throws(ErrorConexion) -> T {
        try await pedir(metodo, ruta, consulta: consulta, cuerpo: nil as SinCuerpo?, token: token)
    }

    private func pedir<T: Decodable, C: Encodable>(
        _ metodo: String, _ ruta: String, consulta: [String: String] = [:], cuerpo: C?, token: String? = nil
    ) async throws(ErrorConexion) -> T {
        var partes = URLComponents(url: base.appending(path: ruta), resolvingAgainstBaseURL: false)!
        if !consulta.isEmpty {
            partes.queryItems = consulta.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var peticion = URLRequest(url: partes.url!)
        peticion.httpMethod = metodo
        if let token {
            peticion.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let cuerpo {
            peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
            peticion.httpBody = try? JSONEncoder().encode(cuerpo)
        }

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await http.data(for: peticion)
        } catch {
            throw .sinConexion
        }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(codigo) else {
            let detalle = try? JSONDecoder().decode(CuerpoError.self, from: datos)
            throw .servidor(codigo: codigo, error: detalle?.error)
        }
        if let vacia = Vacia() as? T { return vacia }
        do {
            return try JSONDecoder().decode(T.self, from: datos)
        } catch {
            throw .respuestaIlegible
        }
    }
}

extension URLSession {
    /// Diez segundos por petición, como en Guardar Enlaces: más, en un móvil,
    /// es tiempo mirando una pantalla que no dice nada.
    public static let conPlazo: URLSession = {
        let configuracion = URLSessionConfiguration.default
        configuracion.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuracion)
    }()
}
