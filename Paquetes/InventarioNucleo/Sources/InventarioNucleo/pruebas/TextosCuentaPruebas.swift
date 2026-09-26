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
                == "Únete a mi hogar en Inventario Casa con el código K7PX3MQA. Caduca el 3 de octubre."
        )
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
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(hogar: "Casa", ultimaPersona: true, conApple: true)
                == "Se eliminan tu cuenta y tus datos del servidor. El hogar Casa y su inventario también se eliminan. "
                + "El inventario se queda en este iPhone. Apple te pedirá que confirmes."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(hogar: "Casa", ultimaPersona: false, conApple: false)
                == "Se eliminan tu cuenta y tus datos del servidor. El hogar sigue para las demás personas. "
                + "El inventario se queda en este iPhone."
        )
        #expect(
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(hogar: nil, ultimaPersona: false, conApple: false)
                == "Se eliminan tu cuenta y tus datos del servidor. El inventario se queda en este iPhone."
        )
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
