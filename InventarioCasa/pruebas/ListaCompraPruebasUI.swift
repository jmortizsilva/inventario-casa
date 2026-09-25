import XCTest

/// Con los datos de ejemplo, en la lista están Leche (Nevera, 0 unidades) y
/// Aceite (Despensa, 1 unidad); Arroz (Despensa, 3 unidades) no.
@MainActor
final class ListaCompraPruebasUI: XCTestCase {
    private var app: XCUIApplication!

    private func abrir(_ argumento: String = "-datosDeEjemplo") {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [argumento]
        app.launch()
    }

    private func irA(_ pestana: String) {
        let boton = app.tabBars.buttons[pestana]
        XCTAssertTrue(boton.waitForExistence(timeout: 5))
        boton.tap()
    }

    private func menu(de fila: String, _ accion: String) {
        app.buttons[fila].press(forDuration: 1.2)
        let boton = app.buttons[accion]
        XCTAssertTrue(boton.waitForExistence(timeout: 3), "No aparece \(accion) en el menú")
        boton.tap()
    }

    func testListaVacia() {
        abrir("-almacenEnMemoria")
        irA("Compra")
        XCTAssertTrue(app.staticTexts["No falta nada"].waitForExistence(timeout: 3))
    }

    func testFilasOrdenadasConCategoria() {
        abrir()
        irA("Compra")
        XCTAssertTrue(app.navigationBars["Lista de la compra"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2 productos"].exists)
        let leche = app.buttons["Leche, agotado, Nevera"]
        let aceite = app.buttons["Aceite, 1 unidad, Despensa"]
        XCTAssertTrue(leche.exists)
        XCTAssertTrue(aceite.exists)
        XCTAssertLessThan(leche.frame.minY, aceite.frame.minY, "Primero lo que tiene menos unidades")
        XCTAssertTrue(leche.staticTexts["Agotado"].exists)
        XCTAssertFalse(app.buttons["Arroz, 3 unidades, Despensa"].exists)
        for etiqueta in ["Leche, agotado, Nevera", "Aceite, 1 unidad, Despensa"] {
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", etiqueta)).count, 1, etiqueta)
        }
    }

    func testReponerSacaDeLaLista() {
        abrir()
        irA("Compra")
        let aceite = app.buttons["Aceite, 1 unidad, Despensa"]
        XCTAssertTrue(aceite.waitForExistence(timeout: 3))
        aceite.buttons["Aumentar cantidad"].tap()
        let dos = app.buttons["Aceite, 2 unidades, Despensa"]
        XCTAssertTrue(dos.waitForExistence(timeout: 3))
        dos.buttons["Aumentar cantidad"].tap()
        XCTAssertTrue(app.buttons["Aceite, 2 unidades, Despensa"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1 producto"].exists)

        irA("Inventario")
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].waitForExistence(timeout: 3))
        app.buttons["Despensa, 2 productos"].tap()
        XCTAssertTrue(app.buttons["Aceite, 3 unidades"].waitForExistence(timeout: 3))
    }

    func testAnadidoAManoSeVeYSePuedeQuitar() {
        abrir()
        app.buttons["Despensa, 2 productos"].tap()
        menu(de: "Arroz, 3 unidades", "Añadir a la lista")
        XCTAssertTrue(app.buttons["Arroz, 3 unidades, en la lista"].waitForExistence(timeout: 3))

        irA("Compra")
        let arroz = app.buttons["Arroz, 3 unidades, Despensa, añadido a mano"]
        XCTAssertTrue(arroz.waitForExistence(timeout: 3))
        menu(de: "Arroz, 3 unidades, Despensa, añadido a mano", "Quitar de la lista")
        XCTAssertTrue(arroz.waitForNonExistence(timeout: 3))
    }

    func testEditarDesdeLaLista() {
        abrir()
        irA("Compra")
        let leche = app.buttons["Leche, agotado, Nevera"]
        XCTAssertTrue(leche.waitForExistence(timeout: 3))
        leche.tap()
        XCTAssertTrue(app.navigationBars["Leche"].waitForExistence(timeout: 3))
        app.steppers["Unidades"].buttons["Increment"].tap()
        app.navigationBars.buttons["Guardar"].tap()
        XCTAssertTrue(app.buttons["Leche, 1 unidad, Nevera"].waitForExistence(timeout: 3))
    }
}
