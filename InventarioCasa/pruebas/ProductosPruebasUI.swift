import XCTest

/// Recorre la pantalla de productos con los datos de ejemplo: Despensa tiene
/// Aceite (1 unidad, en la lista) y Arroz (3 unidades); Limpieza está vacía.
///
/// XCUITest no puede lanzar acciones del rotor: lo que hacen se prueba por los
/// botones de la fila y por el menú de pulsación larga, que llaman al mismo código.
@MainActor
final class ProductosPruebasUI: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-datosDeEjemplo"]
        app.launch()
    }

    private func entrar(en fila: String, titulo: String) {
        let boton = app.buttons[fila]
        XCTAssertTrue(boton.waitForExistence(timeout: 5))
        boton.tap()
        XCTAssertTrue(app.navigationBars[titulo].waitForExistence(timeout: 3))
    }

    private func entrarEnDespensa() {
        entrar(en: "Despensa, 2 productos", titulo: "Despensa")
    }

    private var campoNombre: XCUIElement { app.textFields.firstMatch }
    private var botonGuardar: XCUIElement { app.navigationBars.buttons["Guardar"] }

    private func menu(de fila: String, _ accion: String) {
        app.buttons[fila].press(forDuration: 1.2)
        let boton = app.buttons[accion]
        XCTAssertTrue(boton.waitForExistence(timeout: 3), "No aparece \(accion) en el menú")
        boton.tap()
    }

    func testFilasConUnidadesYLista() {
        entrarEnDespensa()
        XCTAssertTrue(app.buttons["Aceite, 1 unidad, en la lista"].exists)
        XCTAssertTrue(app.buttons["Arroz, 3 unidades"].exists)
        for etiqueta in ["Aceite, 1 unidad, en la lista", "Arroz, 3 unidades"] {
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", etiqueta)).count, 1, etiqueta)
        }
    }

    func testBotonesDeCantidadConZonaDeToqueSuficiente() {
        entrarEnDespensa()
        let fila = app.buttons["Arroz, 3 unidades"]
        for boton in [fila.buttons["Disminuir cantidad"], fila.buttons["Aumentar cantidad"]] {
            // Margen por redondeo: el marco llega como 43,99999.
            XCTAssertGreaterThanOrEqual(boton.frame.width, 43.9)
            XCTAssertGreaterThanOrEqual(boton.frame.height, 43.9)
        }
    }

    func testAumentarYDisminuirCambianLaLista() {
        entrarEnDespensa()
        app.buttons["Arroz, 3 unidades"].buttons["Disminuir cantidad"].tap()
        XCTAssertTrue(app.buttons["Arroz, 2 unidades, en la lista"].waitForExistence(timeout: 3))
        app.buttons["Arroz, 2 unidades, en la lista"].buttons["Aumentar cantidad"].tap()
        XCTAssertTrue(app.buttons["Arroz, 3 unidades"].waitForExistence(timeout: 3))
    }

    func testNoBajaDeCero() {
        entrarEnDespensa()
        let aceite = app.buttons["Aceite, 1 unidad, en la lista"]
        aceite.buttons["Disminuir cantidad"].tap()
        let sinUnidades = app.buttons["Aceite, 0 unidades, en la lista"]
        XCTAssertTrue(sinUnidades.waitForExistence(timeout: 3))
        XCTAssertFalse(sinUnidades.buttons["Disminuir cantidad"].isEnabled)
    }

    func testCrearProducto() {
        entrar(en: "Limpieza, 0 productos", titulo: "Limpieza")
        XCTAssertTrue(app.staticTexts["No hay productos en Limpieza"].exists)

        app.navigationBars.buttons["Añadir producto"].tap()
        XCTAssertTrue(app.navigationBars["Nuevo producto"].waitForExistence(timeout: 3))
        campoNombre.typeText("Lejía")
        // Por posición: la etiqueta cambia con cada toque («Unidades: 1»…).
        let unidades = app.steppers.element(boundBy: 0)
        unidades.buttons["Increment"].tap()
        unidades.buttons["Increment"].tap()
        unidades.buttons["Increment"].tap()
        botonGuardar.tap()

        XCTAssertTrue(app.buttons["Lejía, 3 unidades"].waitForExistence(timeout: 3))
    }

    func testProductoNuevoSinUnidadesEntraEnLaLista() {
        entrar(en: "Limpieza, 0 productos", titulo: "Limpieza")
        app.navigationBars.buttons["Añadir producto"].tap()
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 3))
        campoNombre.typeText("Lejía")
        botonGuardar.tap()
        XCTAssertTrue(app.buttons["Lejía, 0 unidades, en la lista"].waitForExistence(timeout: 3))
    }

    func testNombreRepetidoEnLaMismaCategoria() {
        entrarEnDespensa()
        app.navigationBars.buttons["Añadir producto"].tap()
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 3))
        campoNombre.typeText("arroz")
        botonGuardar.tap()
        XCTAssertTrue(app.staticTexts["Ya hay un producto con ese nombre en Despensa"].waitForExistence(timeout: 3))
    }

    func testEditarProducto() {
        entrarEnDespensa()
        app.buttons["Arroz, 3 unidades"].tap()
        XCTAssertTrue(app.navigationBars["Arroz"].waitForExistence(timeout: 3))
        XCTAssertEqual(campoNombre.value as? String, "Arroz")
        XCTAssertFalse(app.keyboards.element.exists, "Al editar no debe abrirse el teclado")

        app.steppers["Unidades: 3"].buttons["Increment"].tap()
        app.switches["Añadir a la lista cuando queden pocas"].switches.firstMatch.tap()
        XCTAssertFalse(app.steppers["Cuando queden 2 unidades o menos"].exists)
        botonGuardar.tap()

        XCTAssertTrue(app.buttons["Arroz, 4 unidades"].waitForExistence(timeout: 3))
    }

    func testAnadirYQuitarDeLaListaAMano() {
        entrarEnDespensa()
        menu(de: "Arroz, 3 unidades", "Añadir a la lista")
        XCTAssertTrue(app.buttons["Arroz, 3 unidades, en la lista"].waitForExistence(timeout: 3))
        menu(de: "Arroz, 3 unidades, en la lista", "Quitar de la lista")
        XCTAssertTrue(app.buttons["Arroz, 3 unidades"].waitForExistence(timeout: 3))
    }

    func testEliminarProducto() {
        entrarEnDespensa()
        menu(de: "Arroz, 3 unidades", "Eliminar")
        let alerta = app.alerts["¿Eliminar Arroz?"]
        XCTAssertTrue(alerta.waitForExistence(timeout: 3))
        alerta.buttons["Eliminar"].tap()
        XCTAssertTrue(app.buttons["Arroz, 3 unidades"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Aceite, 1 unidad, en la lista"].exists)
    }

    func testAnadirProductoDesdeCategorias() {
        menu(de: "Limpieza, 0 productos", "Añadir producto")
        XCTAssertTrue(app.navigationBars["Nuevo producto"].waitForExistence(timeout: 3))
        campoNombre.typeText("Lejía")
        botonGuardar.tap()
        XCTAssertTrue(app.buttons["Limpieza, 1 producto"].waitForExistence(timeout: 3))
    }
}
