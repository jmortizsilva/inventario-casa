import Foundation
import InventarioConexion
import InventarioNucleo
import Observation

/// La sesión, el hogar y cuándo se sincroniza. Las pantallas llaman aquí y
/// reciben el texto que hay que decir si algo falla: nil es que fue bien o
/// que la persona canceló, y en ese caso no se dice nada.
@MainActor
@Observable
final class Cuenta {
    private(set) var usuario: Usuario?
    private(set) var hogar: Hogar? {
        didSet { recordarHogar() }
    }
    private(set) var sinConexion = false
    private(set) var sesionCaducada = false
    /// Tras iniciar sesión sin hogar: la hoja «Tu hogar».
    var pedirHogar = false
    /// Recién unido a este hogar con cosas en el iPhone: hay que preguntar qué hacer con ellas.
    var decidirInventario: Hogar?
    /// Con la bienvenida delante, Ajustes no presenta nada: la bienvenida se
    /// ocupa de «Tu hogar» y de la alerta del inventario.
    var enBienvenida = false

    let inventario: Inventario
    /// El botón oficial de Apple abre la hoja del sistema, que las pruebas de
    /// interfaz no pueden manejar. Con `-servidorFalso` se usa uno normal.
    let usaBotonAppleDelSistema: Bool
    private let conexion: Conexion
    private let sincronizador: Sincronizador
    private let pedirCodigoGoogle: (URL) async -> Login.Resultado
    private let pedirIdentidadApple: (String) async -> ResultadoApple
    private let ahora: () -> Date
    private var ultimaSincronizacion = Date.distantPast
    private var programada: Task<Void, Never>?

    /// Al volver a la app no se sincroniza si se hizo hace menos de esto:
    /// alternar entre dos apps sería una petición por cada vuelta.
    static let intervaloAlVolver: TimeInterval = 30
    /// Tras un cambio se espera un poco: tocar «+» cinco veces seguidas va en un envío.
    static let esperaTrasCambio: Duration = .seconds(2)

    init(
        inventario: Inventario,
        conexion: Conexion,
        pedirCodigoGoogle: @escaping (URL) async -> Login.Resultado,
        pedirIdentidadApple: @escaping (String) async -> ResultadoApple,
        usaBotonAppleDelSistema: Bool = true,
        ahora: @escaping () -> Date = Date.init
    ) {
        self.inventario = inventario
        self.usaBotonAppleDelSistema = usaBotonAppleDelSistema
        self.conexion = conexion
        sincronizador = Sincronizador(inventario: inventario, conexion: conexion)
        self.pedirCodigoGoogle = pedirCodigoGoogle
        self.pedirIdentidadApple = pedirIdentidadApple
        self.ahora = ahora
    }

    var conSesion: Bool { usuario != nil }

    /// Para los títulos. Sin conexión todavía no se ha preguntado al servidor,
    /// así que se usa el último conocido, si es del hogar en el que sigue el iPhone.
    var nombreDelHogar: String? {
        guard let id = inventario.estado.hogarId else { return nil }
        if let hogar, hogar.id == id { return hogar.nombre }
        guard let recordado = UserDefaults.standard.dictionary(forKey: Self.claveHogar),
              recordado["id"] as? String == id
        else { return nil }
        return recordado["nombre"] as? String
    }

    private static let claveHogar = "ultimoHogar"

    private func recordarHogar() {
        if let hogar {
            UserDefaults.standard.set(["id": hogar.id, "nombre": hogar.nombre], forKey: Self.claveHogar)
        }
    }
    var pendientes: Int { inventario.pendientes.cuantos }

    // MARK: Arranque

    func arrancar() async {
        switch await conexion.restaurar() {
        case .conSesion(let recuperado):
            usuario = recuperado
            await actualizarHogar()
            await sincronizar()
        case .sinConexion(let guardado):
            usuario = guardado
            sinConexion = true
        case .sinSesion:
            usuario = nil
        }
    }

    func alVolver() async {
        guard conSesion, ahora().timeIntervalSince(ultimaSincronizacion) >= Self.intervaloAlVolver else { return }
        await actualizarHogar()
        await sincronizar()
    }

    // MARK: Iniciar y cerrar sesión

    func iniciarConGoogle() async -> String? {
        let url = conexion.urlIniciarGoogle(estado: Login.generarEstado())
        switch await pedirCodigoGoogle(url) {
        case .cancelado:
            return nil
        case .error(let causa):
            return Textos.ErroresCuenta.noIniciada(causa)
        case .exito(let codigo):
            do {
                return await entrar(try await conexion.entrar(conCodigoDeCanje: codigo))
            } catch {
                return Textos.ErroresCuenta.noIniciada(error.causa)
            }
        }
    }

    /// Con el iniciador programático: `-servidorFalso` y pruebas.
    func iniciarConApple() async -> String? {
        let nonce = Login.nonceParaApple()
        return await completarConApple(await pedirIdentidadApple(nonce.resumen), nonce: nonce)
    }

    /// Lo que devuelve el botón oficial de Apple, que tiene su propio circuito.
    func completarConApple(_ resultado: ResultadoApple, nonce: Login.NonceDeApple) async -> String? {
        switch resultado {
        case .cancelado:
            return nil
        case .error:
            return Textos.ErroresCuenta.noIniciada(.proveedorRechaza)
        case .exito(let token, _):
            do {
                return await entrar(try await conexion.entrarConApple(identityToken: token, nonce: nonce.enClaro))
            } catch {
                let causa = error.codigo == 400 ? Login.causa(delError: error.error ?? "") : error.causa
                return Textos.ErroresCuenta.noIniciada(causa)
            }
        }
    }

    private func entrar(_ nuevo: Usuario) async -> String? {
        usuario = nuevo
        sesionCaducada = false
        sinConexion = false
        anunciar(Textos.AnunciosCuenta.sesionIniciada)
        await actualizarHogar()
        if hogar == nil {
            pedirHogar = true
        } else {
            await sincronizar()
        }
        return nil
    }

    /// Lo que no se envió se queda en el iPhone y deja de sincronizarse.
    func cerrarSesion() async {
        programada?.cancel()
        await conexion.cerrarSesion()
        try? inventario.separarDelHogar()
        usuario = nil
        hogar = nil
        anunciar(Textos.AnunciosCuenta.sesionCerrada)
    }

    // MARK: Hogar

    /// Pregunta al servidor en qué hogar está, y arregla el iPhone si no
    /// coincide: alguien lo sacó del hogar, o salió desde otro dispositivo, o
    /// es una instalación nueva de una cuenta que ya tenía hogar.
    func actualizarHogar() async {
        do {
            hogar = try await conexion.hogar()
            sinConexion = false
        } catch {
            fallo(error)
            return
        }
        guard let hogar else {
            if inventario.conHogar { try? inventario.separarDelHogar() }
            return
        }
        guard inventario.estado.hogarId != hogar.id else { return }
        if inventario.categorias.isEmpty {
            try? inventario.unirAHogar(hogar.id, conservando: false)
        } else {
            decidirInventario = hogar
        }
    }

    func crearHogar(nombre: String, tuNombre: String?) async -> String? {
        if let tuNombre, let error = await cambiarNombre(tuNombre, anunciando: false) { return error }
        do {
            let creado = try await conexion.crearHogar(nombre: nombre)
            try inventario.unirAHogar(creado.id, conservando: true)
            hogar = creado
            pedirHogar = false
            anunciar(Textos.AnunciosCuenta.hogarCreado(creado.nombre))
            await sincronizar()
            return nil
        } catch let error as ErrorConexion {
            return Textos.ErroresCuenta.noCreado(error.causa)
        } catch {
            return Textos.Errores.noGuardadoMensaje
        }
    }

    enum ResultadoUnirse {
        case hecho
        /// Había cosas en el iPhone: el formulario pregunta y llama a `resolverInventario`.
        case preguntar(Hogar)
        case error(String)
    }

    func unirse(codigo: String, tuNombre: String?) async -> ResultadoUnirse {
        if let tuNombre, let error = await cambiarNombre(tuNombre, anunciando: false) { return .error(error) }
        let unido: Hogar
        do {
            unido = try await conexion.unirse(codigo: codigo.trimmingCharacters(in: .whitespaces))
        } catch {
            switch error.codigo {
            case 404: return .error(Textos.ErroresCuenta.codigoNoSirve)
            case 429: return .error(Textos.ErroresCuenta.demasiadosIntentos)
            default: return .error(Textos.ErroresCuenta.noUnido(error.causa))
            }
        }
        hogar = unido
        // Sin tocar pedirHogar: el formulario vive dentro de «Tu hogar», y
        // cerrarla aquí se lo llevaría antes de preguntar. La cierra él al terminar.
        guard inventario.categorias.isEmpty else {
            // El anuncio espera a la respuesta: con la alerta delante se perdería.
            return .preguntar(unido)
        }
        await resolverInventario(unido, conservando: false)
        return .hecho
    }

    /// La respuesta a «Inventario de este iPhone» al unirse.
    func resolverInventario(_ unido: Hogar, conservando: Bool) async {
        decidirInventario = nil
        do {
            try inventario.unirAHogar(unido.id, conservando: conservando)
        } catch {
            anunciar(Textos.Errores.noGuardadoMensaje)
            return
        }
        anunciar(Textos.AnunciosCuenta.unido(unido.nombre))
        await sincronizar()
    }

    func invitar() async -> Result<Invitacion, MensajeError> {
        do {
            return .success(try await conexion.invitar())
        } catch {
            return .failure(MensajeError(texto: Textos.ErroresCuenta.noInvitado(error.causa)))
        }
    }

    func salir() async -> String? {
        let nombre = hogar?.nombre ?? ""
        do {
            try await conexion.salir()
        } catch {
            // Si el servidor dice que ya no estaba, el resultado es el que se quería.
            guard error.codigo == 409 else { return Textos.ErroresCuenta.noSalido(error.causa) }
        }
        try? inventario.separarDelHogar()
        hogar = nil
        anunciar(Textos.AnunciosCuenta.salido(nombre))
        return nil
    }

    // MARK: Cuenta

    func cambiarNombre(_ nombre: String, anunciando: Bool = true) async -> String? {
        do {
            usuario = try await conexion.cambiarNombre(Nombres.limpiar(nombre))
            if anunciando { anunciar(Textos.Anuncios.guardado(usuario?.nombre ?? nombre)) }
            await actualizarHogar()
            return nil
        } catch {
            return Textos.ErroresCuenta.nombreNoGuardado(error.causa)
        }
    }

    /// Con Apple, antes hay que identificarse otra vez: su código es lo que
    /// permite al servidor revocar el acceso, como exige Apple.
    func eliminarCuenta() async -> String? {
        var codigoApple: String?
        if usuario?.esDeApple == true {
            switch await pedirIdentidadApple(Login.nonceParaApple().resumen) {
            case .cancelado: return nil
            case .error: return Textos.ErroresCuenta.cuentaNoEliminada(.appleNoConfirma)
            case .exito(_, let codigo): codigoApple = codigo
            }
        }
        do {
            try await conexion.eliminarCuenta(codigoApple: codigoApple)
        } catch {
            let causa: Textos.Causa = switch (error.codigo, error.error) {
            case (400, "codigo_apple_no_valido"), (400, "falta_codigo_apple"): .appleNoConfirma
            case (502, _): .sinHablarConApple
            default: error.causa
            }
            return Textos.ErroresCuenta.cuentaNoEliminada(causa)
        }
        programada?.cancel()
        try? inventario.separarDelHogar()
        usuario = nil
        hogar = nil
        anunciar(Textos.AnunciosCuenta.cuentaEliminada)
        return nil
    }

    // MARK: Sincronizar

    /// Tras cada cambio en el inventario. Si llega otro antes de la espera,
    /// se empieza a contar de nuevo.
    func programarSincronizacion() {
        guard conSesion, inventario.conHogar else { return }
        programada?.cancel()
        programada = Task {
            try? await Task.sleep(for: Self.esperaTrasCambio)
            guard !Task.isCancelled else { return }
            await sincronizar()
        }
    }

    /// No dice nada: el estado se ve en Ajustes. Lo que no se envía sigue en la cola.
    func sincronizar() async {
        guard conSesion, inventario.conHogar else { return }
        do {
            try await sincronizador.sincronizar()
            sinConexion = false
            ultimaSincronizacion = ahora()
        } catch let error as ErrorConexion {
            fallo(error)
        } catch {
            // Fallo al guardar en el iPhone: se reintentará en la siguiente.
        }
    }

    private func fallo(_ error: ErrorConexion) {
        switch error {
        case .sinConexion:
            sinConexion = true
        case .sesionCaducada:
            // El hogar y la cola se conservan: al volver a iniciar sesión se envía lo pendiente.
            usuario = nil
            sesionCaducada = true
        case .servidor(409, _):
            // El servidor ya no lo tiene en ningún hogar.
            try? inventario.separarDelHogar()
            hogar = nil
        default:
            break
        }
    }
}

struct MensajeError: Error {
    let texto: String
}
