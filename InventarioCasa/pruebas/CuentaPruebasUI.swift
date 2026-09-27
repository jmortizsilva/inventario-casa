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
        XCTAssertTrue(app.staticTexts["En el hogar: Ana"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["En el hogar: Luis y Eva"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sesión iniciada con Apple"].exists)
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
