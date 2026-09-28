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
    /// El código de un enlace de invitación que se acaba de abrir, mientras se
    /// atiende. Mientras lo hay, «Tu hogar» no sale al iniciar sesión: sigue la invitación.
    var invitacion: String?
    /// Si al abrir el enlace ya había hogar: entonces solo sale «Ya estás en…»,
    /// sin hoja. Se decide al abrirlo y no después, para que la hoja no se
    /// cierre sola si el hogar aparece al iniciar sesión desde ella.
    private(set) var invitacionConHogar = false
    /// Con la bienvenida delante, Ajustes no presenta nada: la bienvenida se
    /// ocupa de «Tu hogar» y de la alerta del inventario.
    var enBienvenida = false

    /// Lo que quiere recibir esta cuenta. Nil hasta que se pregunta al servidor.
    private(set) var avisos: Avisos?
    /// iOS tiene denegadas las notificaciones de la app: se dice en Ajustes.
    private(set) var permisoDenegado = false
    private let permiso: PermisoNotificaciones
    /// El de APNs de este iPhone, para quitarlo al cerrar sesión.
    private var tokenDispositivo: String?

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
    private var sondeo: Task<Void, Never>?
    private var sincronizando = false
    private var repetirSincronizacion = false

    /// Al volver a la app no se sincroniza si se hizo hace menos de esto:
    /// alternar entre dos apps sería una petición por cada vuelta.
    static let intervaloAlVolver: TimeInterval = 30
    static let intervaloSondeo: Duration = .seconds(15)
    /// Tras un cambio se espera un poco: tocar «+» cinco veces seguidas va en un envío.
    static let esperaTrasCambio: Duration = .seconds(2)

    init(
        inventario: Inventario,
        conexion: Conexion,
        pedirCodigoGoogle: @escaping (URL) async -> Login.Resultado,
        pedirIdentidadApple: @escaping (String) async -> ResultadoApple,
        usaBotonAppleDelSistema: Bool = true,
        permiso: PermisoNotificaciones = .sistema,
        ahora: @escaping () -> Date = Date.init
    ) {
        self.permiso = permiso
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
            await cargarAvisos()
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

    /// Un enlace que abre la app. Solo se hace caso a los de invitación.
    func abrirEnlace(_ url: URL) {
        guard let codigo = EnlaceInvitacion.codigo(de: url) else { return }
        invitacionConHogar = hogar != nil
        invitacion = codigo
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
            // Con una invitación abierta, lo siguiente es unirse a ese hogar.
            pedirHogar = invitacion == nil
        } else {
            await sincronizar()
        }
        return nil
    }

    /// Lo que no se envió se queda en el iPhone y deja de sincronizarse.
    func cerrarSesion() async {
        programada?.cancel()
        await olvidarDispositivo()
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
            // Mientras la app lleve un solo hogar: el que ya tenía el iPhone, o el primero.
            let lista = try await conexion.hogares()
            hogar = lista.first { $0.id == inventario.estado.hogarId } ?? lista.first
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
        invitacion = nil
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
        do throws(ErrorConexion) {
            guard let id = hogar?.id else { throw ErrorConexion.servidor(codigo: 404, error: nil) }
            return .success(try await conexion.invitar(hogar: id))
        } catch {
            return .failure(MensajeError(texto: Textos.ErroresCuenta.noInvitado(error.causa)))
        }
    }

    func salir() async -> String? {
        let nombre = hogar?.nombre ?? ""
        do {
            if let id = hogar?.id { try await conexion.salir(hogar: id) }
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
        // El servidor ya ha borrado los dispositivos de la cuenta.
        tokenDispositivo = nil
        avisos = nil
        try? inventario.separarDelHogar()
        usuario = nil
        hogar = nil
        anunciar(Textos.AnunciosCuenta.cuentaEliminada)
        return nil
    }

    // MARK: Notificaciones

    #if DEBUG
    private static let entorno = EntornoAvisos.desarrollo
    #else
    private static let entorno = EntornoAvisos.produccion
    #endif

    /// Al abrir Ajustes. Si hay alguna activada, se vuelve a pedir el token:
    /// iOS puede cambiarlo, y así el servidor tiene siempre el último.
    func cargarAvisos() async {
        guard conSesion, let id = hogar?.id else { return }
        guard let cargados = try? await conexion.avisos(hogar: id) else { return }
        avisos = cargados
        guard cargados.algunoActivo else { return }
        switch await permiso.estado() {
        case .concedido:
            permisoDenegado = false
            permiso.registrar()
        case .denegado:
            permisoDenegado = true
        case .sinPreguntar:
            break
        }
    }

    /// Activar pide permiso a iOS si aún no se ha pedido. Si se deniega, el
    /// interruptor se queda como estaba y se dice por qué.
    func cambiarAviso(_ cual: WritableKeyPath<Avisos, Bool>, a valor: Bool) async {
        guard var nuevos = avisos else { return }
        if valor {
            switch await permiso.estado() {
            case .denegado:
                permisoDenegado = true
                return
            case .sinPreguntar:
                guard await permiso.pedir() else {
                    permisoDenegado = true
                    return
                }
            case .concedido:
                break
            }
            permisoDenegado = false
            permiso.registrar()
        }
        nuevos[keyPath: cual] = valor
        do {
            guard let id = hogar?.id else { return }
            avisos = try await conexion.cambiarAvisos(nuevos, hogar: id)
        } catch {
            anunciar(Textos.ErroresCuenta.avisoNoGuardado(error.causa))
        }
    }

    /// Lo llama el delegado de la app cuando iOS da el token.
    func recibirToken(_ token: String) async {
        tokenDispositivo = token
        guard conSesion else { return }
        try? await conexion.registrarDispositivo(token, entorno: Self.entorno)
    }

    /// Antes de cerrar sesión: después ya no hay sesión con la que pedirlo, y
    /// este iPhone seguiría recibiendo las notificaciones de la cuenta.
    private func olvidarDispositivo() async {
        if let token = tokenDispositivo {
            try? await conexion.quitarDispositivo(token)
        }
        tokenDispositivo = nil
        avisos = nil
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
    ///
    /// Se piden desde tres sitios (el sondeo, un cambio propio y volver a la
    /// app), y dos a la vez mandarían la misma cola dos veces. Si llega una
    /// con otra en curso, se apunta y se hace al terminar la primera.
    func sincronizar() async {
        guard conSesion, inventario.conHogar else { return }
        guard !sincronizando else {
            repetirSincronizacion = true
            return
        }
        sincronizando = true
        defer { sincronizando = false }
        repeat {
            repetirSincronizacion = false
            do {
                try await sincronizador.sincronizar()
                sinConexion = false
                ultimaSincronizacion = ahora()
            } catch let error as ErrorConexion {
                fallo(error)
            } catch {
                // Fallo al guardar en el iPhone: se reintentará en la siguiente.
            }
        } while repetirSincronizacion && conSesion && inventario.conHogar
    }

    /// Mientras la app está abierta y delante, se pregunta cada 15 segundos:
    /// lo que haga otra persona no llegaba hasta cerrar y volver a abrir la
    /// app. En segundo plano no se pregunta nada.
    func empezarASondear() {
        sondeo?.cancel()
        sondeo = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.intervaloSondeo)
                guard !Task.isCancelled else { return }
                await sincronizar()
            }
        }
    }

    func dejarDeSondear() {
        sondeo?.cancel()
        sondeo = nil
    }

    private func fallo(_ error: ErrorConexion) {
        switch error {
        case .sinConexion:
            sinConexion = true
        case .sesionCaducada:
            // El hogar y la cola se conservan: al volver a iniciar sesión se envía lo pendiente.
            usuario = nil
            sesionCaducada = true
        case .servidor(404, _), .servidor(409, _):
            // Ya no está en ese hogar: lo sacaron, o salió desde otro dispositivo.
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
