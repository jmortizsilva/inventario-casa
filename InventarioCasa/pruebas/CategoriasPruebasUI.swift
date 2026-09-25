import XCTest

/// Recorre la pantalla de categorías en el simulador. Las etiquetas que se
/// buscan son las que lee VoiceOver (ver `docs/textos-interfaz.md`).
///
/// XCUITest no puede lanzar acciones del rotor, así que cambiar el nombre y
/// eliminar se prueban por el menú de pulsación larga, que llama al mismo código.
@MainActor
final class CategoriasPruebasUI: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func abrir(_ argumento: String = "-almacenEnMemoria") {
        app = XCUIApplication()
        app.launchArguments = [argumento]
        app.launch()
    }

    private var botonAnadir: XCUIElement { app.navigationBars.buttons["Añadir categoría"] }
    private var campoNombre: XCUIElement { app.textFields.firstMatch }
    private var botonGuardar: XCUIElement { app.navigationBars.buttons["Guardar"] }

    private func crear(_ nombre: String) {
        botonAnadir.tap()
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 3))
        campoNombre.typeText(nombre)
        botonGuardar.tap()
    }

    private func menu(de fila: String, _ accion: String) {
        app.buttons[fila].press(forDuration: 1.2)
        let boton = app.buttons[accion]
        XCTAssertTrue(boton.waitForExistence(timeout: 3), "No aparece \(accion) en el menú")
        boton.tap()
    }

    func testSinCategoriasSeOfreceAnadir() {
        abrir()
        XCTAssertTrue(app.staticTexts["No hay categorías"].waitForExistence(timeout: 5))
        XCTAssertTrue(botonAnadir.exists)
    }

    func testCrearCategoria() {
        abrir()
        crear("Despensa")
        XCTAssertTrue(app.buttons["Despensa, 0 productos"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No hay categorías"].exists)
    }

    func testGuardarDesactivadoSinNombre() {
        abrir()
        botonAnadir.tap()
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 3))
        XCTAssertFalse(botonGuardar.isEnabled)
        campoNombre.typeText("   ")
        XCTAssertFalse(botonGuardar.isEnabled)
    }

    func testNombreRepetidoSeExplicaYNoSeCierra() {
        abrir()
        crear("Despensa")
        crear("despensa")
        XCTAssertTrue(app.staticTexts["Ya hay una categoría con ese nombre"].waitForExistence(timeout: 3))
        XCTAssertTrue(botonGuardar.exists, "La hoja debería seguir abierta")
    }

    func testCancelarNoCrea() {
        abrir()
        botonAnadir.tap()
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 3))
        campoNombre.typeText("Nevera")
        app.navigationBars.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["No hay categorías"].waitForExistence(timeout: 3))
    }

    func testCambiarNombre() {
        abrir()
        crear("Despensa")
        menu(de: "Despensa, 0 productos", "Cambiar nombre")

        XCTAssertTrue(app.navigationBars["Cambiar nombre"].waitForExistence(timeout: 3))
        XCTAssertEqual(campoNombre.value as? String, "Despensa")
        campoNombre.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "Nevera")
        botonGuardar.tap()

        XCTAssertTrue(app.buttons["Nevera, 0 productos"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Despensa, 0 productos"].exists)
    }

    func testEliminarCategoriaVacia() {
        abrir()
        crear("Despensa")
        menu(de: "Despensa, 0 productos", "Eliminar")

        let alerta = app.alerts["¿Eliminar Despensa?"]
        XCTAssertTrue(alerta.waitForExistence(timeout: 3))
        alerta.buttons["Eliminar"].tap()
        XCTAssertTrue(app.staticTexts["No hay categorías"].waitForExistence(timeout: 3))
    }

    func testEliminarCategoriaConProductosAvisaYSePuedeCancelar() {
        abrir("-datosDeEjemplo")
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].exists)

        menu(de: "Despensa, 2 productos", "Eliminar")
        let alerta = app.alerts["¿Eliminar Despensa?"]
        XCTAssertTrue(alerta.waitForExistence(timeout: 3))
        XCTAssertTrue(alerta.staticTexts["También se eliminarán sus 2 productos."].exists)

        alerta.buttons["Cancelar"].tap()
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].exists)

        menu(de: "Despensa, 2 productos", "Eliminar")
        // Hay que esperar a la alerta: un toque durante su animación se pierde.
        let otraVez = app.alerts["¿Eliminar Despensa?"]
        XCTAssertTrue(otraVez.waitForExistence(timeout: 3))
        otraVez.buttons["Eliminar"].tap()
        // waitForExistence daría verdadero mientras dura la animación de borrado.
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Nevera, 1 producto"].exists)
    }

    /// Con .accessibilityElement(children: .ignore) cada fila salía como dos
    /// botones anidados con la misma etiqueta, y VoiceOver podía leerla dos veces.
    func testCadaFilaEsUnSoloElemento() {
        abrir("-datosDeEjemplo")
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].waitForExistence(timeout: 5))
        for etiqueta in ["Despensa, 2 productos", "Limpieza, 0 productos", "Nevera, 1 producto"] {
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", etiqueta)).count, 1, etiqueta)
        }
    }

    func testAbrirCategoria() {
        abrir("-datosDeEjemplo")
        app.buttons["Limpieza, 0 productos"].tap()
        XCTAssertTrue(app.navigationBars["Limpieza"].waitForExistence(timeout: 3))
    }
}
