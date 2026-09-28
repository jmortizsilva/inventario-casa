import Foundation
import Testing
@testable import InventarioNucleo

/// Contrato, como `TextosPruebas`: si cambia uno, se cambia aquí y en
/// `docs/textos-interfaz.md`, apartado «Cuenta y hogar».
@Suite struct TextosCuentaPruebas {
    @Test func sesionIniciada() {
        #expect(Textos.Sesion.iniciadaComo("ana@ejemplo.com") == "Sesión iniciada como ana@ejemplo.com")
        #expect(Textos.Sesion.iniciadaComo("x7k2mq@privaterelay.appleid.com") == "Sesión iniciada con Apple")
    }

    @Test func titulosConElHogar() {
        #expect(Textos.titulo("Inventario", hogar: "Casa") == "Inventario - Casa")
        #expect(Textos.titulo("Lista de la compra", hogar: nil) == "Lista de la compra")
    }

    @Test func estadoDeLaSincronizacion() {
        #expect(Textos.estadoSincronizacion(pendientes: 0, sinConexion: false) == "Todo enviado")
        #expect(Textos.estadoSincronizacion(pendientes: 1, sinConexion: false) == "1 cambio sin enviar")
        #expect(Textos.estadoSincronizacion(pendientes: 3, sinConexion: false) == "3 cambios sin enviar")
        #expect(Textos.estadoSincronizacion(pendientes: 0, sinConexion: true) == "Sin conexión")
        #expect(Textos.estadoSincronizacion(pendientes: 2, sinConexion: true) == "Sin conexión, 2 cambios sin enviar")
    }

    @Test func personasDelHogar() {
        #expect(Textos.Hogar.personas(["Ana"]) == "En el hogar: Ana")
        #expect(Textos.Hogar.personas(["Ana", "Luis"]) == "En el hogar: Ana y Luis")
        #expect(Textos.Hogar.personas(["Ana", "Luis", "Eva"]) == "En el hogar: Ana, Luis y Eva")
    }

    @Test func loQuePasaAlHogar() {
        #expect(
            Textos.Hogar.pasaAlHogar(categorias: 2, productos: 15)
                == "Tu inventario de este iPhone pasa al hogar: 2 categorías y 15 productos."
        )
        #expect(
            Textos.Hogar.pasaAlHogar(categorias: 1, productos: 1)
                == "Tu inventario de este iPhone pasa al hogar: 1 categoría y 1 producto."
        )
        #expect(Textos.Hogar.pasaAlHogar(categorias: 3, productos: 0) == "Tu inventario de este iPhone pasa al hogar: 3 categorías.")
        #expect(Textos.Hogar.pasaAlHogar(categorias: 0, productos: 0) == nil)
    }

    @Test func preguntaAlUnirseConCosasEnElIphone() {
        #expect(
            Textos.InventarioEnElIphone.pregunta(categorias: 2, productos: 5, hogar: "Casa")
                == "Hay 2 categorías y 5 productos en este iPhone. ¿Los añades a Casa? Si no, se eliminan de este iPhone."
        )
        #expect(
            Textos.InventarioEnElIphone.pregunta(categorias: 1, productos: 0, hogar: "Casa")
                == "Hay 1 categoría en este iPhone. ¿Las añades a Casa? Si no, se eliminan de este iPhone."
        )
        #expect(Textos.InventarioEnElIphone.anadir(soloCategorias: false) == "Añadirlos")
        #expect(Textos.InventarioEnElIphone.eliminar(soloCategorias: true) == "Eliminarlas")
    }

    @Test func invitacion() {
        // 3 de octubre de 2026 a las 10:00 en Madrid.
        let caduca = Date(timeIntervalSince1970: 1_791_014_400)
        let madrid = TimeZone(identifier: "Europe/Madrid")!
        #expect(
            Textos.Invitacion.mensaje(codigo: "K7PX3MQA", caduca: caduca, zona: madrid)
                == "K7PX3MQA. Sirve una vez y caduca el 3 de octubre."
        )
        #expect(
            Textos.Invitacion.textoCompartido(codigo: "K7PX3MQA", caduca: caduca, zona: madrid)
                == "Únete a mi hogar en Inventario Casa: https://inventario.jmortiz.es/unirse/K7PX3MQA\n"
                + "Si no se abre la app, escribe el código K7PX3MQA en Ajustes, Unirme con un código. "
                + "Caduca el 3 de octubre."
        )
        #expect(Textos.Invitacion.iniciaParaUnirte == "Para unirte a un hogar, inicia sesión.")
        #expect(Textos.Invitacion.yaEnHogarTitulo("Casa") == "Ya estás en Casa")
        #expect(Textos.Invitacion.yaEnHogarMensaje == "Para unirte a otro, sal antes de este.")
    }

    @Test func confirmaciones() {
        #expect(Textos.ConfirmacionCuenta.salirTitulo("Casa") == "¿Salir de Casa?")
        #expect(
            Textos.ConfirmacionCuenta.salirMensaje(ultimaPersona: false)
                == "El inventario se queda en este iPhone, pero deja de compartirse. Para volver hará falta otro código."
        )
        #expect(
            Textos.ConfirmacionCuenta.cerrarSesionMensaje(pendientes: 1)
                == "Hay 1 cambio sin enviar. Si cierras sesión, se quedan solo en este iPhone."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(soloTuyos: ["Casa"], compartidos: [], conApple: true)
                == "Se eliminan tu cuenta y tus datos del servidor. El hogar Casa y su inventario también se eliminan. "
                + "El inventario se queda en este iPhone. Para confirmarlo, Apple te pedirá que inicies sesión otra vez. "
                + "No se abre ninguna sesión nueva: es solo para poder eliminarla."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(soloTuyos: [], compartidos: ["Casa"], conApple: false)
                == "Se eliminan tu cuenta y tus datos del servidor. El hogar sigue para las demás personas. "
                + "El inventario se queda en este iPhone."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(soloTuyos: ["Casa", "Playa"], compartidos: ["Piso"], conApple: false)
                == "Se eliminan tu cuenta y tus datos del servidor. Los hogares Casa y Playa, con su inventario, "
                + "también se eliminan. Piso sigue para las demás personas. El inventario se queda en este iPhone."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(soloTuyos: [], compartidos: [], conApple: false)
                == "Se eliminan tu cuenta y tus datos del servidor. El inventario se queda en este iPhone."
        )
        #expect(
            Textos.ConfirmacionCuenta.salirMensaje(ultimaPersona: false, conOtros: true)
                == "Su inventario se quita de este iPhone. Para volver hará falta otro código."
        )
        #expect(
            Textos.ConfirmacionCuenta.salirMensaje(ultimaPersona: true, conOtros: true)
                == "Eres la única persona del hogar: se eliminará del servidor dentro de 30 días. "
                + "Su inventario se quita de este iPhone."
        )
    }

    @Test func variosHogares() {
        #expect(Textos.Hogares.encabezado == "Hogares")
        #expect(Textos.Hogares.actual == "Hogar actual")
        #expect(Textos.Hogares.filaActual("Casa") == "Casa, hogar actual")
        #expect(Textos.Hogares.abrir == "Abrir")
        #expect(Textos.Hogares.abrirEste == "Abrir este hogar")
        #expect(Textos.Hogares.cambiado("Playa") == "Hogar actual, Playa")
        #expect(Textos.ErroresCuenta.yaEnEseHogar == "Ya estás en ese hogar.")
        #expect(Textos.ErroresCuenta.limiteHogares == "Ya estás en 10 hogares, que es el máximo.")
    }

    @Test func anunciosYErrores() {
        #expect(Textos.AnunciosCuenta.hogarCreado("Casa") == "Hogar creado, Casa")
        #expect(Textos.AnunciosCuenta.unido("Casa") == "Unido al hogar, Casa")
        #expect(Textos.AnunciosCuenta.salido("Casa") == "Has salido de Casa")
        #expect(Textos.ErroresCuenta.noIniciada(.sinConexion) == "No se ha iniciado sesión. Sin conexión.")
        #expect(
            Textos.ErroresCuenta.noIniciada(.sinCorreo)
                == "No se ha iniciado sesión. Tu cuenta no ha dado ningún correo, y hace falta."
        )
        #expect(
            Textos.ErroresCuenta.noIniciada(.proveedorRechaza)
                == "No se ha iniciado sesión. No se aceptó el inicio de sesión. Prueba otra vez."
        )
        #expect(
            Textos.ErroresCuenta.cuentaNoEliminada(.appleNoConfirma)
                == "No se ha eliminado la cuenta. Apple no ha confirmado. Prueba otra vez."
        )
    }

    @Test func elManualExplicaCompartir() {
        #expect(Textos.manual.last?.titulo == "Compartir con tu casa")
    }
}

@Suite struct EnlaceInvitacionPruebas {
    @Test func leeElCodigo() {
        #expect(EnlaceInvitacion.codigo(de: URL(string: "https://inventario.jmortiz.es/unirse/K7PX3MQA")!) == "K7PX3MQA")
        #expect(EnlaceInvitacion.codigo(de: URL(string: "https://inventario.jmortiz.es/unirse/k7px3mqa")!) == "K7PX3MQA")
        #expect(EnlaceInvitacion.codigo(de: URL(string: "https://inventario.jmortiz.es/unirse/K7PX3MQA/")!) == "K7PX3MQA")
    }

    @Test func loQueNoEsUnaInvitacionNoSeLee() {
        for texto in [
            "https://otro.ejemplo.com/unirse/K7PX3MQA",
            "http://inventario.jmortiz.es/unirse/K7PX3MQA",
            "https://inventario.jmortiz.es/hogar/K7PX3MQA",
            "https://inventario.jmortiz.es/unirse/",
            "https://inventario.jmortiz.es/unirse/K7PX%3Cb%3E",
            "https://inventario.jmortiz.es/unirse/K7PX3MQA/otra",
        ] {
            #expect(EnlaceInvitacion.codigo(de: URL(string: texto)!) == nil, "\(texto)")
        }
    }

    @Test func formaElEnlace() {
        #expect(EnlaceInvitacion.url(codigo: "K7PX3MQA").absoluteString == "https://inventario.jmortiz.es/unirse/K7PX3MQA")
    }
}

@Suite struct TextosNotificacionesPruebas {
    @Test func seccionDeAjustes() {
        #expect(Textos.Notificaciones.encabezado == "Notificaciones")
        #expect(
            [
                Textos.Notificaciones.productosNuevos, Textos.Notificaciones.categoriasNuevas,
                Textos.Notificaciones.entraEnLista, Textos.Notificaciones.saleDeLista,
                Textos.Notificaciones.personasNuevas,
            ] == [
                "Productos nuevos", "Categorías nuevas", "Lo que entra en la lista",
                "Lo que sale de la lista", "Personas nuevas en el hogar",
            ]
        )
        #expect(Textos.Notificaciones.pie == "Solo avisa de lo que hacen las demás personas del hogar.")
        #expect(
            Textos.Notificaciones.desactivadas
                == "Las notificaciones están desactivadas para Inventario Casa en Ajustes del iPhone."
        )
        #expect(Textos.Notificaciones.abrirAjustes == "Abrir Ajustes")
        #expect(Textos.ErroresCuenta.avisoNoGuardado(.sinConexion) == "No se ha guardado. Sin conexión.")
    }
}
