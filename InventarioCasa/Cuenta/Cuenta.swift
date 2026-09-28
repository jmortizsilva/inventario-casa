import Foundation
import InventarioAlmacen
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
    /// Los hogares de la cuenta, en el orden en que se unió a cada uno.
    private(set) var hogares: [Hogar] = [] {
        didSet { recordarNombres() }
    }
    /// El abierto en el iPhone.
    var hogar: Hogar? { hogares.first { $0.id == inventario.estado.hogarId } }
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
    /// Lo que quiere recibir de cada hogar, según se va preguntando al
    /// servidor. Se configura cada uno aunque no sea el actual.
    private(set) var avisosPorHogar: [String: Avisos] = [:]
    /// iOS tiene denegadas las notificaciones de la app: se dice en Ajustes.
    private(set) var permisoDenegado = false
    private let permiso: PermisoNotificaciones
    /// El de APNs de este iPhone, para quitarlo al cerrar sesión.
    private var tokenDispositivo: String?

    let inventarios: Inventarios
    /// El del hogar abierto. Cambia al cambiar de hogar.
    var inventario: Inventario { inventarios.actual }
    /// El botón oficial de Apple abre la hoja del sistema, que las pruebas de
    /// interfaz no pueden manejar. Con `-servidorFalso` se usa uno normal.
    let usaBotonAppleDelSistema: Bool
    private let conexion: Conexion
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
        inventarios: Inventarios,
        conexion: Conexion,
        pedirCodigoGoogle: @escaping (URL) async -> Login.Resultado,
        pedirIdentidadApple: @escaping (String) async -> ResultadoApple,
        usaBotonAppleDelSistema: Bool = true,
        permiso: PermisoNotificaciones = .sistema,
        ahora: @escaping () -> Date = Date.init
    ) {
        self.permiso = permiso
        self.inventarios = inventarios
        self.usaBotonAppleDelSistema = usaBotonAppleDelSistema
        self.conexion = conexion
        self.pedirCodigoGoogle = pedirCodigoGoogle
        self.pedirIdentidadApple = pedirIdentidadApple
        self.ahora = ahora
    }

    var conSesion: Bool { usuario != nil }

    /// Para los títulos. Sin conexión todavía no se ha preguntado al servidor,
    /// así que se usa el último nombre conocido de ese hogar.
    var nombreDelHogar: String? {
        guard let id = inventario.estado.hogarId else { return nil }
        if let hogar { return hogar.nombre }
        return (UserDefaults.standard.dictionary(forKey: Self.claveNombres) as? [String: String])?[id]
    }

    private static let claveNombres = "nombresDeHogares"

    private func recordarNombres() {
        guard !hogares.isEmpty else { return }
        let nombres = Dictionary(hogares.map { ($0.id, $0.nombre) }, uniquingKeysWith: { a, _ in a })
        UserDefaults.standard.set(nombres, forKey: Self.claveNombres)
    }
    var pendientes: Int { inventario.pendientes.cuantos }

    // MARK: Arranque

    func arrancar() async {
        switch await conexion.restaurar() {
        case .conSesion(let recuperado):
            usuario = recuperado
            await actualizarHogar()
            await sincronizar()
            await enviarPendientesDeOtros()
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
        try? inventarios.cerrarSesion()
        usuario = nil
        hogares = []
        anunciar(Textos.AnunciosCuenta.sesionCerrada)
    }

    // MARK: Hogar

    /// Pregunta al servidor en qué hogares está, y arregla el iPhone si no
    /// coincide: alguien lo sacó de uno, salió desde otro dispositivo, o es una
    /// instalación nueva de una cuenta que ya tenía hogares.
    func actualizarHogar() async {
        let lista: [Hogar]
        do {
            lista = try await conexion.hogares()
            sinConexion = false
        } catch {
            fallo(error)
            return
        }
        hogares = lista
        try? inventarios.quitarLosQueNoEstan(en: lista.map(\.id))
        // La primera vez con esta cuenta en este iPhone: lo que hay sin hogar va
        // al primero de sus hogares, o se pregunta qué hacer con ello.
        guard !inventarios.registro.conHogares, let primero = lista.first else { return }
        if inventario.categorias.isEmpty {
            try? inventarios.entrar(en: primero.id, conservando: false)
        } else {
            decidirInventario = primero
        }
    }

    func crearHogar(nombre: String, tuNombre: String?) async -> String? {
        if let tuNombre, let error = await cambiarNombre(tuNombre, anunciando: false) { return error }
        do {
            let creado = try await conexion.crearHogar(nombre: nombre)
            // Lo pendiente del que se deja, antes de dejarlo.
            if inventarios.registro.conHogares { await sincronizar() }
            // El primero se queda con lo que ya había en el iPhone; los demás empiezan vacíos.
            try inventarios.entrar(en: creado.id, conservando: true)
            hogares.append(creado)
            pedirHogar = false
            anunciar(Textos.AnunciosCuenta.hogarCreado(creado.nombre))
            await sincronizar()
            return nil
        } catch let error as ErrorConexion {
            if error.error == "limite_hogares" { return Textos.ErroresCuenta.limiteHogares }
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
            switch (error.codigo, error.error) {
            case (404, _): return .error(Textos.ErroresCuenta.codigoNoSirve)
            case (429, _): return .error(Textos.ErroresCuenta.demasiadosIntentos)
            case (409, "ya_en_este_hogar"): return .error(Textos.ErroresCuenta.yaEnEseHogar)
            case (409, "limite_hogares"): return .error(Textos.ErroresCuenta.limiteHogares)
            default: return .error(Textos.ErroresCuenta.noUnido(error.causa))
            }
        }
        hogares.append(unido)
        // Con otros hogares, este tiene su propio inventario, que llega del servidor.
        if inventarios.registro.conHogares {
            await sincronizar()
            await resolverInventario(unido, conservando: false)
            return .hecho
        }
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
            try inventarios.entrar(en: unido.id, conservando: conservando)
        } catch {
            anunciar(Textos.Errores.noGuardadoMensaje)
            return
        }
        anunciar(Textos.AnunciosCuenta.unido(unido.nombre))
        await sincronizar()
    }

    /// Sin hogar, el abierto.
    func invitar(a hogar: Hogar? = nil) async -> Result<Invitacion, MensajeError> {
        do throws(ErrorConexion) {
            guard let id = (hogar ?? self.hogar)?.id else { throw ErrorConexion.servidor(codigo: 404, error: nil) }
            return .success(try await conexion.invitar(hogar: id))
        } catch {
            return .failure(MensajeError(texto: Textos.ErroresCuenta.noInvitado(error.causa)))
        }
    }

    /// Salir para siempre de un hogar (sin decir cuál, del abierto). Si quedan
    /// otros, se abre el siguiente y el inventario de este se borra del iPhone.
    func salir(de cual: Hogar? = nil) async -> String? {
        guard let saliente = cual ?? hogar else { return nil }
        do {
            try await conexion.salir(hogar: saliente.id)
        } catch {
            // Si el servidor dice que ya no estaba, el resultado es el que se quería.
            guard error.codigo == 404 || error.codigo == 409 else { return Textos.ErroresCuenta.noSalido(error.causa) }
        }
        dejarHogar(saliente.id)
        anunciar(Textos.AnunciosCuenta.salido(saliente.nombre))
        await sincronizar()
        return nil
    }

    /// Cambiar el inventario abierto a otro hogar de la cuenta, y decirlo. No borra nada:
    /// lo pendiente del que se deja se envía antes, y si no hay conexión se
    /// queda guardado en su inventario hasta la próxima.
    func cambiar(a destino: Hogar) async -> String? {
        guard destino.id != hogar?.id else { return nil }
        await sincronizar()
        do {
            try inventarios.cambiar(a: destino.id)
        } catch {
            return Textos.Errores.noGuardadoMensaje
        }
        anunciar(Textos.Hogares.cambiado(destino.nombre))
        await sincronizar()
        await cargarAvisos()
        return nil
    }

    /// Quitar un hogar del iPhone y de la lista, sin hablar con el servidor.
    private func dejarHogar(_ id: String) {
        let siguiente = hogares.first { $0.id != id }?.id
        try? inventarios.salir(de: id, siguiente: siguiente)
        hogares.removeAll { $0.id == id }
        avisosPorHogar = [:]
    }

    /// Antes de cerrar sesión: lo pendiente de todos los hogares, porque al
    /// cerrar se quitan del iPhone los que no son el actual. Devuelve cuántos
    /// cambios han quedado sin enviar.
    func enviarTodo() async -> Int {
        await sincronizar()
        await enviarPendientesDeOtros()
        return pendientes + inventarios.otrosConPendientes().reduce(0) { $0 + $1.pendientes.cuantos }
    }

    /// Los cambios sin enviar de los hogares que no están abiertos.
    private func enviarPendientesDeOtros() async {
        for otro in inventarios.otrosConPendientes() {
            try? await Sincronizador(inventario: otro, conexion: conexion).sincronizar()
        }
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
        avisosPorHogar = [:]
        try? inventarios.cerrarSesion()
        usuario = nil
        hogares = []
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
    /// Las de un hogar; sin decir cuál, las del actual.
    func cargarAvisos(de cual: String? = nil) async {
        guard conSesion, let id = cual ?? hogar?.id else { return }
        guard let cargados = try? await conexion.avisos(hogar: id) else { return }
        avisosPorHogar[id] = cargados
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
    func cambiarAviso(_ cual: WritableKeyPath<Avisos, Bool>, a valor: Bool, en hogar: String) async {
        guard var nuevos = avisosPorHogar[hogar] else { return }
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
            avisosPorHogar[hogar] = try await conexion.cambiarAvisos(nuevos, hogar: hogar)
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
        avisosPorHogar = [:]
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
                try await Sincronizador(inventario: inventario, conexion: conexion).sincronizar()
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
            if let id = inventario.estado.hogarId { dejarHogar(id) }
        default:
            break
        }
    }
}

struct MensajeError: Error {
    let texto: String
}
