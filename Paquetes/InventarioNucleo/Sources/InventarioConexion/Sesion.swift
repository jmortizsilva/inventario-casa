import Foundation

/// Al abrir la app con una sesión de otra vez.
public enum Restauracion: Equatable, Sendable {
    case conSesion(Usuario)
    case sinSesion
    /// Hay sesión guardada pero no se ha podido renovar. Sigue valiendo: se
    /// vuelve a intentar al sincronizar. `usuario` es el guardado, si lo había.
    case sinConexion(Usuario?)
}

/// La sesión: token de acceso en memoria y lo demás en el llavero.
///
/// Un actor no basta para que dos renovaciones no se crucen: mientras una
/// espera al servidor, otra llamada puede entrar y renovar con el mismo token,
/// y el servidor revoca la segunda porque el token rota al usarse. Por eso la
/// renovación en curso se comparte (`renovando`).
public actor Sesion {
    private let cliente: ClienteApi
    private let credenciales: AlmacenCredenciales
    private var tokenAcceso: String?
    private var renovando: Task<Void, any Error>?
    public private(set) var usuario: Usuario?

    public init(cliente: ClienteApi, credenciales: AlmacenCredenciales) {
        self.cliente = cliente
        self.credenciales = credenciales
        usuario = (try? credenciales.leer())?.usuario
    }

    public var hayGuardada: Bool { (try? credenciales.leer()) != nil }

    public func entrar(conCodigoDeCanje codigo: String) async throws(ErrorConexion) -> Usuario {
        try aplicar(await cliente.canjear(codigo: codigo))
    }

    public func entrarConApple(identityToken: String, nonce: String) async throws(ErrorConexion) -> Usuario {
        try aplicar(await cliente.entrarConApple(identityToken: identityToken, nonce: nonce))
    }

    public func restaurar() async -> Restauracion {
        guard hayGuardada else { return .sinSesion }
        do {
            try await renovar()
            return usuario.map(Restauracion.conSesion) ?? .sinSesion
        } catch .sesionCaducada {
            return .sinSesion
        } catch {
            return .sinConexion(usuario)
        }
    }

    /// Si el servidor no contesta, la sesión se cierra aquí igual: lo que no
    /// puede pasar es que el botón no haga nada.
    public func cerrar() async {
        if let guardada = try? credenciales.leer() {
            try? await cliente.cerrarSesion(tokenRefresco: guardada.tokenRefresco)
        }
        olvidar()
    }

    /// Tras eliminar la cuenta, cuando ya no hay sesión que cerrar en el servidor.
    public func olvidar() {
        try? credenciales.borrar()
        tokenAcceso = nil
        usuario = nil
    }

    public func actualizar(_ nuevo: Usuario) {
        usuario = nuevo
        if let guardada = try? credenciales.leer() {
            try? credenciales.guardar(SesionGuardada(tokenRefresco: guardada.tokenRefresco, usuario: nuevo))
        }
    }

    /// Ejecuta algo que necesita el token de acceso. Si el servidor dice que
    /// ha caducado, renueva una vez y lo repite.
    public func conToken<T: Sendable>(
        _ peticion: @Sendable (String) async throws(ErrorConexion) -> T
    ) async throws(ErrorConexion) -> T {
        if tokenAcceso == nil { try await renovar() }
        guard let token = tokenAcceso else { throw .sesionCaducada }
        do {
            return try await peticion(token)
        } catch .servidor(codigo: 401, _) {
            tokenAcceso = nil
            try await renovar()
            guard let renovado = tokenAcceso else { throw .sesionCaducada }
            return try await peticion(renovado)
        }
    }

    // MARK: Auxiliares

    /// Quien llega mientras hay una renovación en curso espera a esa misma,
    /// que es la que guarda el token nuevo: así nadie despierta antes de que
    /// esté guardado.
    private func renovar() async throws(ErrorConexion) {
        if renovando == nil {
            guard let guardada = try? credenciales.leer() else { throw .sesionCaducada }
            renovando = Task { try await self.renovarAhora(guardada.tokenRefresco) }
        }
        do {
            try await renovando!.value
        } catch {
            throw error as? ErrorConexion ?? .sinConexion
        }
    }

    private func renovarAhora(_ tokenRefresco: String) async throws(ErrorConexion) {
        defer { renovando = nil }
        do {
            try aplicar(try await cliente.renovar(tokenRefresco: tokenRefresco))
        } catch {
            // Solo un 401 dice que el token ya no vale. Sin conexión se
            // conserva: borrarlo cerraría la sesión por abrir la app en un sótano.
            if error.codigo == 401 {
                olvidar()
                throw .sesionCaducada
            }
            throw error
        }
    }

    @discardableResult
    private func aplicar(_ respuesta: RespuestaSesion) throws(ErrorConexion) -> Usuario {
        tokenAcceso = respuesta.tokenAcceso
        if let recibido = respuesta.usuario { usuario = recibido }
        // El token de refresco rota: el anterior queda revocado al usarse, así
        // que si el nuevo no se guarda, la siguiente apertura no podrá renovar.
        do {
            try credenciales.guardar(SesionGuardada(tokenRefresco: respuesta.tokenRefresco, usuario: usuario))
        } catch {
            throw .respuestaIlegible
        }
        guard let usuario else { throw .respuestaIlegible }
        return usuario
    }
}
