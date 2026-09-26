import Foundation

/// Textos de la cuenta, el hogar y la sincronización. Revisados en
/// `docs/textos-interfaz.md`, apartado «Cuenta y hogar».
extension Textos {

    // MARK: Bienvenida

    public enum Bienvenida {
        public static let titulo = "Inventario Casa"
        public static let queEs = "Lleva la cuenta de lo que hay en casa y de lo que falta comprar."
        public static let cuenta =
            "Con cuenta, compartes el inventario con tu casa y lo tienes en varios dispositivos. "
            + "Sin cuenta, la app funciona igual, pero todo se queda en este iPhone."
        public static let usarSinCuenta = "Usar sin cuenta"
        public static let masTarde = "Puedes iniciar sesión más tarde desde Ajustes."
    }

    // MARK: Sesión

    public enum Sesion {
        public static let encabezado = "Cuenta"
        public static let sinCuenta = "Sin cuenta, el inventario se guarda solo en este iPhone."
        /// El botón de Apple lo pinta iOS con este mismo texto; el de Google
        /// se llama igual para que los dos se lean parecido.
        public static let iniciarConGoogle = "Iniciar sesión con Google"
        public static let pistaIniciar = "Para compartir el inventario con tu casa"
        /// Se avisa de Safari porque iOS pregunta antes si se permite usar el
        /// dominio para iniciar sesión, y esa pregunta sale de la nada si no se ha dicho.
        public static let pistaGoogle = "Se abre Safari para confirmar tu cuenta"
        public static let cerrarSesion = "Cerrar sesión"
        public static let eliminarCuenta = "Eliminar cuenta"
        public static let caducada = "La sesión ha caducado. Vuelve a iniciarla."

        /// El correo oculto de Apple es una ristra de letras que no dice nada
        /// leída en voz alta.
        public static func iniciadaComo(_ correo: String) -> String {
            correo.lowercased().hasSuffix("@privaterelay.appleid.com")
                ? "Sesión iniciada con Apple"
                : "Sesión iniciada como \(correo)"
        }
    }

    // MARK: Estado de la sincronización

    public static func estadoSincronizacion(pendientes n: Int, sinConexion: Bool) -> String {
        let cambios = n == 1 ? "1 cambio sin enviar" : "\(n) cambios sin enviar"
        switch (sinConexion, n) {
        case (false, 0): return "Todo enviado"
        case (false, _): return cambios
        case (true, 0): return "Sin conexión"
        case (true, _): return "Sin conexión, \(cambios)"
        }
    }

    // MARK: Hogar

    public enum Hogar {
        public static let encabezadoSinHogar = "Hogar"
        public static let sinHogar = "No estás en ningún hogar."
        public static let tituloElegir = "Tu hogar"
        public static let explicacion =
            "Un hogar es un inventario compartido. Crea el tuyo o únete al de otra persona con su código."
        public static let crear = "Crear hogar"
        public static let unirmeConCodigo = "Unirme con un código"
        public static let ahoraNo = "Ahora no"

        public static let tituloNuevo = "Nuevo hogar"
        public static let campoNombreHogar = "Nombre del hogar"
        public static let campoTuNombre = "Tu nombre"
        public static let pistaTuNombre = "Así te verán las demás personas del hogar"
        public static let botonCrear = "Crear"

        public static let tituloUnirme = "Unirme a un hogar"
        public static let campoCodigo = "Código"
        public static let explicacionCodigo = "Pide el código a alguien del hogar."
        public static let botonUnirme = "Unirme"

        public static let invitar = "Invitar a alguien"
        public static let salir = "Salir del hogar"
        public static let cambiarTuNombre = "Cambiar tu nombre"

        /// «En el hogar: Ana», «Ana y Luis», «Ana, Luis y Eva».
        public static func personas(_ nombres: [String]) -> String {
            "En el hogar: " + enumerar(nombres)
        }

        /// Al crear un hogar con cosas ya guardadas en el iPhone.
        public static func pasaAlHogar(categorias: Int, productos: Int) -> String? {
            resumen(categorias: categorias, productos: productos).map {
                "Tu inventario de este iPhone pasa al hogar: \($0)."
            }
        }
    }

    // MARK: Lo que había en el iPhone al unirse

    public enum InventarioEnElIphone {
        public static let titulo = "Inventario de este iPhone"

        /// «Los» o «las» según lo que haya: solo categorías es femenino.
        public static func pregunta(categorias: Int, productos: Int, hogar: String) -> String {
            let que = resumen(categorias: categorias, productos: productos) ?? ""
            let pronombre = productos == 0 ? "Las" : "Los"
            return "Hay \(que) en este iPhone. ¿\(pronombre) añades a \(hogar)? "
                + "Si no, se eliminan de este iPhone."
        }

        public static func anadir(soloCategorias: Bool) -> String {
            soloCategorias ? "Añadirlas" : "Añadirlos"
        }

        public static func eliminar(soloCategorias: Bool) -> String {
            soloCategorias ? "Eliminarlas" : "Eliminarlos"
        }
    }

    // MARK: Invitar

    public enum Invitacion {
        public static let titulo = "Código de invitación"
        public static let compartir = "Compartir"

        public static func mensaje(codigo: String, caduca: Date, zona: TimeZone = .current) -> String {
            "\(codigo). Sirve una vez y caduca el \(fecha(caduca, zona: zona))."
        }

        public static func textoCompartido(codigo: String, caduca: Date, zona: TimeZone = .current) -> String {
            "Únete a mi hogar en Inventario Casa con el código \(codigo). Caduca el \(fecha(caduca, zona: zona))."
        }
    }

    // MARK: Confirmaciones de cuenta y hogar

    public enum ConfirmacionCuenta {
        public static func salirTitulo(_ hogar: String) -> String { "¿Salir de \(hogar)?" }
        public static let salirBoton = "Salir"

        public static func salirMensaje(ultimaPersona: Bool) -> String {
            ultimaPersona
                ? "Eres la única persona del hogar: se eliminará del servidor dentro de 30 días. "
                    + "El inventario se queda en este iPhone."
                : "El inventario se queda en este iPhone, pero deja de compartirse. "
                    + "Para volver hará falta otro código."
        }

        public static let cerrarSesionTitulo = "¿Cerrar sesión?"

        public static func cerrarSesionMensaje(pendientes n: Int) -> String {
            let cambios = n == 1 ? "Hay 1 cambio sin enviar" : "Hay \(n) cambios sin enviar"
            return "\(cambios). Si cierras sesión, se quedan solo en este iPhone."
        }

        public static let eliminarCuentaTitulo = "¿Eliminar tu cuenta?"

        /// `hogar` es nil si no está en ninguno.
        public static func eliminarCuentaMensaje(hogar: String?, ultimaPersona: Bool, conApple: Bool) -> String {
            var partes = ["Se eliminan tu cuenta y tus datos del servidor."]
            if let hogar {
                partes.append(
                    ultimaPersona
                        ? "El hogar \(hogar) y su inventario también se eliminan."
                        : "El hogar sigue para las demás personas."
                )
            }
            partes.append("El inventario se queda en este iPhone.")
            if conApple {
                partes.append("Apple te pedirá que confirmes.")
            }
            return partes.joined(separator: " ")
        }
    }

    // MARK: Anuncios y errores de cuenta y hogar

    public enum AnunciosCuenta {
        public static let sesionIniciada = "Sesión iniciada"
        public static let sesionCerrada = "Sesión cerrada"
        public static let cuentaEliminada = "Cuenta eliminada"
        public static func hogarCreado(_ hogar: String) -> String { "Hogar creado, \(hogar)" }
        public static func unido(_ hogar: String) -> String { "Unido al hogar, \(hogar)" }
        public static func salido(_ hogar: String) -> String { "Has salido de \(hogar)" }
    }

    /// Por qué falló algo que habla con el servidor. La acción la pone quien
    /// llama («No se ha creado el hogar.»); aquí solo la causa.
    public enum Causa: Sendable, Equatable {
        case sinConexion
        case servidorNoResponde
        case appleNoConfirma
        case sinHablarConApple

        public var texto: String {
            switch self {
            case .sinConexion: "Sin conexión."
            case .servidorNoResponde: "El servidor no responde. Prueba más tarde."
            case .appleNoConfirma: "Apple no ha confirmado. Prueba otra vez."
            case .sinHablarConApple: "No se pudo hablar con Apple. Prueba más tarde."
            }
        }
    }

    public enum ErroresCuenta {
        public static let codigoNoSirve = "Ese código no sirve. Puede que haya caducado o que ya se haya usado."
        public static let demasiadosIntentos = "Demasiados intentos. Prueba dentro de una hora."

        public static func noIniciada(_ causa: Causa) -> String { "No se ha iniciado sesión. \(causa.texto)" }
        public static func noCreado(_ causa: Causa) -> String { "No se ha creado el hogar. \(causa.texto)" }
        public static func noUnido(_ causa: Causa) -> String { "No te has unido. \(causa.texto)" }
        public static func noSalido(_ causa: Causa) -> String { "No has salido del hogar. \(causa.texto)" }
        public static func noInvitado(_ causa: Causa) -> String { "No se ha creado el código. \(causa.texto)" }
        public static func nombreNoGuardado(_ causa: Causa) -> String { "No se ha guardado el nombre. \(causa.texto)" }
        public static func cuentaNoEliminada(_ causa: Causa) -> String { "No se ha eliminado la cuenta. \(causa.texto)" }
    }

    public static let apartadoCompartir = Apartado(
        titulo: "Compartir con tu casa",
        texto: "En Ajustes, inicia sesión y crea un hogar. Con Invitar a alguien sale un código: quien lo escriba en Unirme con un código comparte el inventario contigo. Los cambios llegan a todos cuando hay conexión; sin ella, la app funciona igual y los envía después."
    )

    // MARK: Auxiliares

    /// «1 categoría y 3 productos», solo con lo que no sea cero. Nil si no hay nada.
    static func resumen(categorias: Int, productos: Int) -> String? {
        var partes: [String] = []
        if categorias > 0 { partes.append(categorias == 1 ? "1 categoría" : "\(categorias) categorías") }
        if productos > 0 { partes.append(Textos.productos(productos)) }
        return partes.isEmpty ? nil : partes.joined(separator: " y ")
    }

    static func enumerar(_ nombres: [String]) -> String {
        switch nombres.count {
        case 0: return ""
        case 1: return nombres[0]
        default: return nombres.dropLast().joined(separator: ", ") + " y " + nombres[nombres.count - 1]
        }
    }

    /// «3 de octubre»: se lee, no se descifra.
    static func fecha(_ fecha: Date, zona: TimeZone) -> String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zona
        let partes = calendario.dateComponents([.day, .month], from: fecha)
        let meses = [
            "enero", "febrero", "marzo", "abril", "mayo", "junio",
            "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
        ]
        return "\(partes.day ?? 1) de \(meses[(partes.month ?? 1) - 1])"
    }
}
