import XCTest

/// Cuenta y hogar contra el servidor en memoria (`-servidorFalso`): Google
/// entra como Ana, con nombre; Apple como alguien sin nombre; y el hogar de
/// Luis admite el código LUISCASA. Los textos son los de
/// `docs/textos-interfaz.md`, apartado «Cuenta y hogar».
@MainActor
final class CuentaPruebasUI: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func abrir(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-almacenEnMemoria", "-servidorFalso"] + extra
        app.launch()
    }

    private func irAAjustes() {
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 3))
    }

    private func pulsar(_ boton: String) {
        let elemento = app.buttons[boton].firstMatch
        XCTAssertTrue(elemento.waitForExistence(timeout: 5), "No aparece \(boton)")
        elemento.tap()
    }

    private func escribir(_ texto: String, en campo: String) {
        let elemento = app.textFields[campo]
        XCTAssertTrue(elemento.waitForExistence(timeout: 3), "No aparece el campo \(campo)")
        elemento.tap()
        elemento.typeText(texto)
    }

    /// Espera a que exista la alerta antes de pulsar: un toque durante la animación se pierde.
    private func responderAlerta(_ titulo: String, _ boton: String) {
        let alerta = app.alerts[titulo]
        XCTAssertTrue(alerta.waitForExistence(timeout: 5), "No aparece la alerta \(titulo)")
        alerta.buttons[boton].tap()
        XCTAssertTrue(alerta.waitForNonExistence(timeout: 5))
    }

    /// La fila de un hogar en Ajustes lleva a su pantalla.
    private func entrarEnHogar(_ fila: String, titulo: String) {
        pulsar(fila)
        XCTAssertTrue(app.navigationBars[titulo].waitForExistence(timeout: 5), "No se abre \(titulo)")
    }

    private func crearCategoria(_ nombre: String) {
        app.navigationBars.buttons["Añadir"].tap()
        pulsar("Categoría")
        app.textFields.firstMatch.typeText(nombre)
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.buttons["\(nombre), 0 productos"].waitForExistence(timeout: 3))
    }

    // MARK: Bienvenida

    func testBienvenidaSinCuenta() {
        abrir(["-conBienvenida"])
        XCTAssertTrue(app.navigationBars["Inventario Casa"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Iniciar sesión con Apple"].exists)
        XCTAssertTrue(app.buttons["Iniciar sesión con Google"].exists)
        XCTAssertTrue(app.staticTexts["Puedes iniciar sesión más tarde desde Ajustes."].exists)

        pulsar("Usar sin cuenta")
        XCTAssertTrue(app.tabBars.buttons["Inventario"].waitForExistence(timeout: 5))
        irAAjustes()
        XCTAssertTrue(app.staticTexts["Sin cuenta, el inventario se guarda solo en este iPhone."].exists)
    }

    func testBienvenidaConGoogleYTuHogar() {
        abrir(["-conBienvenida"])
        pulsar("Iniciar sesión con Google")
        XCTAssertTrue(app.navigationBars["Tu hogar"].waitForExistence(timeout: 5))
        pulsar("Ahora no")
        XCTAssertTrue(app.tabBars.buttons["Inventario"].waitForExistence(timeout: 5))
        irAAjustes()
        XCTAssertTrue(app.staticTexts["Sesión iniciada como ana@ejemplo.com"].exists)
        XCTAssertTrue(app.staticTexts["No estás en ningún hogar."].exists)
    }

    // MARK: Hogar

    func testCrearHogarInvitarYSalir() throws {
        abrir()
        crearCategoria("Despensa")
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        XCTAssertTrue(app.navigationBars["Tu hogar"].waitForExistence(timeout: 5))
        pulsar("Crear hogar")
        XCTAssertTrue(app.navigationBars["Nuevo hogar"].waitForExistence(timeout: 3))
        // Google da el nombre: no se pide.
        XCTAssertFalse(app.textFields["Tu nombre"].exists)
        XCTAssertTrue(app.staticTexts["Tu inventario de este iPhone pasa al hogar: 1 categoría."].exists)
        escribir("Casa", en: "Nombre del hogar")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()

        XCTAssertTrue(app.navigationBars["Nuevo hogar"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Casa, hogar actual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Todo enviado"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Ajustes - Casa"].exists)
        app.tabBars.buttons["Inventario"].tap()
        let barra = app.navigationBars["Inventario - Casa"]
        XCTAssertTrue(barra.waitForExistence(timeout: 3))
        // En la barra, el título antes que el botón: es el orden en que los recorre VoiceOver.
        let etiquetas = barra.descendants(matching: .any).allElementsBoundByIndex.map(\.label)
        let titulo = try XCTUnwrap(etiquetas.firstIndex(of: "Inventario - Casa"))
        let anadir = try XCTUnwrap(etiquetas.firstIndex(of: "Añadir"))
        XCTAssertLessThan(titulo, anadir)
        app.tabBars.buttons["Ajustes"].tap()

        entrarEnHogar("Casa, hogar actual", titulo: "Casa")
        XCTAssertTrue(app.staticTexts["En el hogar: Ana"].exists)
        // Es el actual: no se ofrece abrirlo.
        XCTAssertFalse(app.buttons["Abrir este hogar"].exists)
        pulsar("Invitar a alguien")
        responderAlerta("Código de invitación", "Aceptar")

        pulsar("Salir del hogar")
        responderAlerta("¿Salir de Casa?", "Salir")
        XCTAssertTrue(app.staticTexts["No estás en ningún hogar."].waitForExistence(timeout: 5))
        // El inventario se queda en el iPhone.
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Despensa, 0 productos"].waitForExistence(timeout: 3))
    }

    func testUnirseConAppleYTuNombre() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Apple")
        pulsar("Unirme con un código")
        XCTAssertTrue(app.navigationBars["Unirme a un hogar"].waitForExistence(timeout: 3))
        let unirme = app.navigationBars["Unirme a un hogar"].buttons["Unirme"]
        escribir("LUISCASA", en: "Código")
        // Apple no da el nombre: hasta ponerlo no se puede.
        XCTAssertFalse(unirme.isEnabled)
        escribir("Eva", en: "Tu nombre")
        unirme.tap()

        XCTAssertTrue(app.navigationBars["Unirme a un hogar"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sesión iniciada con Apple"].waitForExistence(timeout: 5))
        entrarEnHogar("Casa de Luis, hogar actual", titulo: "Casa de Luis")
        XCTAssertTrue(app.staticTexts["En el hogar: Luis y Eva"].exists)
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Compra"].tap()
        XCTAssertTrue(app.navigationBars["Lista de la compra - Casa de Luis"].waitForExistence(timeout: 3))
    }

    func testUnirseConCosasEnElIphonePregunta() {
        abrir()
        crearCategoria("Despensa")
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Unirme con un código")
        escribir("LUISCASA", en: "Código")
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()

        responderAlerta("Inventario de este iPhone", "Añadirlas")
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Despensa, 0 productos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].waitForExistence(timeout: 5))
    }

    func testCodigoQueNoSirve() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Unirme con un código")
        escribir("MALO2222", en: "Código")
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()
        XCTAssertTrue(
            app.staticTexts["Ese código no sirve. Puede que haya caducado o que ya se haya usado."]
                .waitForExistence(timeout: 5)
        )
    }

    // MARK: Varios hogares

    func testVariosHogaresConSuInventarioCadaUno() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Crear hogar")
        escribir("Casa", en: "Nombre del hogar")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.buttons["Casa, hogar actual"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inventario"].tap()
        crearCategoria("Despensa")

        // Otro hogar desde la lista: pasa a ser el actual y empieza vacío.
        app.tabBars.buttons["Ajustes"].tap()
        pulsar("Crear hogar")
        escribir("Playa", en: "Nombre del hogar")
        // Sin elegir nada: de entrada no se copia.
        XCTAssertTrue(app.buttons["Nada"].isSelected)
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.buttons["Playa, hogar actual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Casa"].exists)
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.navigationBars["Inventario - Playa"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No hay categorías"].exists)

        // Volver a Casa desde su pantalla: sigue con lo suyo.
        app.tabBars.buttons["Ajustes"].tap()
        entrarEnHogar("Casa", titulo: "Casa")
        pulsar("Abrir este hogar")
        XCTAssertTrue(app.buttons["Abrir este hogar"].waitForNonExistence(timeout: 5))
        // De vuelta a la lista: la pestaña conserva la pantalla en la que se quedó.
        app.navigationBars["Casa"].buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.navigationBars["Inventario - Casa"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Despensa, 0 productos"].exists)

        // Salir de Playa teniendo Casa: su inventario se quita del iPhone.
        app.tabBars.buttons["Ajustes"].tap()
        entrarEnHogar("Playa", titulo: "Playa")
        pulsar("Salir del hogar")
        let alerta = app.alerts["¿Salir de Playa?"]
        XCTAssertTrue(alerta.waitForExistence(timeout: 5))
        XCTAssertTrue(
            alerta.staticTexts["Eres la única persona del hogar: se eliminará del servidor dentro de 30 días. "
                + "Su inventario se quita de este iPhone."].exists
        )
        alerta.buttons["Salir"].tap()
        XCTAssertTrue(app.buttons["Playa"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Casa, hogar actual"].exists)
    }

    func testCrearOtroHogarCopiandoDelActual() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Crear hogar")
        escribir("Casa", en: "Nombre del hogar")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.buttons["Casa, hogar actual"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Inventario"].tap()
        crearCategoria("Despensa")
        entrarEnHogar("Despensa, 0 productos", titulo: "Despensa")
        app.navigationBars.buttons["Añadir producto"].tap()
        XCTAssertTrue(app.navigationBars["Nuevo producto"].waitForExistence(timeout: 3))
        app.textFields.firstMatch.typeText("Arroz")
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.buttons["Arroz, 0 unidades, en la lista"].waitForExistence(timeout: 3))
        app.navigationBars["Despensa"].buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Ajustes"].tap()
        pulsar("Crear hogar")
        escribir("Playa", en: "Nombre del hogar")
        XCTAssertTrue(app.staticTexts["Casa se queda como está."].exists)
        pulsar("Categorías y productos")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.buttons["Playa, hogar actual"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.navigationBars["Inventario - Playa"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Despensa, 1 producto"].waitForExistence(timeout: 3))

        // Casa sigue con lo suyo.
        app.tabBars.buttons["Ajustes"].tap()
        entrarEnHogar("Casa", titulo: "Casa")
        pulsar("Abrir este hogar")
        XCTAssertTrue(app.buttons["Abrir este hogar"].waitForNonExistence(timeout: 5))
        app.navigationBars["Casa"].buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.navigationBars["Inventario - Casa"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Despensa, 1 producto"].exists)
    }

    func testUnirseTeniendoYaUnHogar() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Crear hogar")
        escribir("Casa", en: "Nombre del hogar")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.buttons["Casa, hogar actual"].waitForExistence(timeout: 5))

        pulsar("Unirme con un código")
        escribir("LUISCASA", en: "Código")
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()
        // Sin preguntar por lo del iPhone: el hogar nuevo trae lo suyo.
        XCTAssertTrue(app.buttons["Casa de Luis, hogar actual"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].waitForExistence(timeout: 5))
    }

    // MARK: Enlace de invitación

    private let enlaceDeLuis = "https://inventario.jmortiz.es/unirse/luiscasa"

    func testEnlaceSinSesion() {
        abrir(["-abrirEnlace", enlaceDeLuis])
        XCTAssertTrue(app.staticTexts["Para unirte a un hogar, inicia sesión."].waitForExistence(timeout: 5))
        pulsar("Iniciar sesión con Google")
        // Sigue con el código ya escrito, sin pasar por «Tu hogar».
        let codigo = app.textFields["Código"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 5))
        XCTAssertEqual(codigo.value as? String, "LUISCASA")
        XCTAssertFalse(app.navigationBars["Tu hogar"].exists)
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()
        XCTAssertTrue(app.navigationBars["Unirme a un hogar"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Inventario - Casa de Luis"].waitForExistence(timeout: 5))
    }

    func testEnlaceConLaBienvenidaDelante() {
        abrir(["-conBienvenida", "-abrirEnlace", enlaceDeLuis])
        XCTAssertTrue(app.navigationBars["Inventario Casa"].waitForExistence(timeout: 5))
        pulsar("Iniciar sesión con Google")
        let codigo = app.textFields["Código"]
        XCTAssertTrue(codigo.waitForExistence(timeout: 5))
        XCTAssertEqual(codigo.value as? String, "LUISCASA")
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].waitForExistence(timeout: 5))
    }

    func testEnlaceCancelado() {
        abrir(["-abrirEnlace", enlaceDeLuis])
        XCTAssertTrue(app.staticTexts["Para unirte a un hogar, inicia sesión."].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["Para unirte a un hogar, inicia sesión."].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Inventario"].exists)
    }

    // MARK: Sondeo

    /// Lo que añade otra persona llega con la app abierta, sin cerrarla:
    /// antes solo llegaba al volver a abrirla.
    func testLoDeOtraPersonaLlegaSinCerrarLaApp() {
        abrir(["-cambioAjeno"])
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Unirme con un código")
        escribir("LUISCASA", en: "Código")
        app.navigationBars["Unirme a un hogar"].buttons["Unirme"].tap()
        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].waitForExistence(timeout: 5))
        // Luis añade Yogures a los 20 segundos de arrancar; el sondeo es cada 15.
        XCTAssertTrue(app.buttons["Nevera, 2 productos"].waitForExistence(timeout: 45))
    }

    // MARK: Notificaciones

    /// Crea «Casa» y entra en su pantalla, que es donde están sus notificaciones.
    private func crearHogarConGoogle(_ extra: [String] = []) {
        abrir(extra)
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Crear hogar")
        escribir("Casa", en: "Nombre del hogar")
        app.navigationBars["Nuevo hogar"].buttons["Crear"].tap()
        XCTAssertTrue(app.navigationBars["Nuevo hogar"].waitForNonExistence(timeout: 5))
        entrarEnHogar("Casa, hogar actual", titulo: "Casa")
    }

    /// El interruptor de verdad está dentro de la fila: tocar la fila no lo cambia.
    private func interruptor(_ nombre: String) -> XCUIElement {
        let fila = app.switches[nombre]
        XCTAssertTrue(fila.waitForExistence(timeout: 5), "No aparece \(nombre)")
        return fila
    }

    func testActivarUnaNotificacion() {
        crearHogarConGoogle()
        let productos = interruptor("Productos nuevos")
        XCTAssertEqual(productos.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Solo avisa de lo que hacen las demás personas del hogar."].exists)
        productos.switches.firstMatch.tap()
        // Se activa al contestar el servidor, no al tocar.
        wait(for: [expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: productos)], timeout: 5)
        XCTAssertFalse(app.staticTexts["Las notificaciones están desactivadas para Inventario Casa en Ajustes del iPhone."].exists)
    }

    func testSinPermisoSeDiceYNoSeActiva() {
        crearHogarConGoogle(["-sinPermisoNotificaciones"])
        let productos = interruptor("Productos nuevos")
        productos.switches.firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Las notificaciones están desactivadas para Inventario Casa en Ajustes del iPhone."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Abrir Ajustes"].exists)
        XCTAssertEqual(productos.value as? String, "0")
    }

    // MARK: Cuenta

    func testEliminarCuenta() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Ahora no")
        pulsar("Eliminar cuenta")
        responderAlerta("¿Eliminar tu cuenta?", "Eliminar cuenta")
        XCTAssertTrue(app.buttons["Iniciar sesión con Google"].waitForExistence(timeout: 5))
    }

    func testCerrarSesionSinPendientesNoPregunta() {
        abrir()
        irAAjustes()
        pulsar("Iniciar sesión con Google")
        pulsar("Ahora no")
        pulsar("Cerrar sesión")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["Iniciar sesión con Google"].waitForExistence(timeout: 5))
    }
}
