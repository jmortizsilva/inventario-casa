import XCTest

@MainActor
final class AjustesPruebasUI: XCTestCase {
    func testVersionYManual() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-almacenEnMemoria"]
        app.launch()

        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Versión 2.0.0"].exists)

        app.buttons["Manual"].tap()
        XCTAssertTrue(app.navigationBars["Manual"].waitForExistence(timeout: 3))
        for titulo in ["Categorías y productos", "Cambiar las unidades", "Lista de la compra", "Eliminar"] {
            XCTAssertTrue(app.scrollViews.staticTexts[titulo].exists, titulo)
        }

        app.navigationBars["Manual"].buttons["Cerrar"].tap()
        XCTAssertTrue(app.navigationBars["Manual"].waitForNonExistence(timeout: 3))
    }
}
