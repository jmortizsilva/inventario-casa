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
        for titulo in ["Categorías y productos", "Cambiar la cantidad", "Lista de la compra", "Eliminar", "Compartir con tu casa"] {
            XCTAssertTrue(app.scrollViews.staticTexts[titulo].exists, titulo)
        }

        app.navigationBars["Manual"].buttons["Cerrar"].tap()
        XCTAssertTrue(app.navigationBars["Manual"].waitForNonExistence(timeout: 3))
    }

    /// Las hojas de «Añadir a Siri» son de Apple: aquí solo se comprueba que
    /// se abren; lo que se guarda se prueba en el iPhone. Las frases guardadas
    /// se conservan en el simulador de una prueba a otra, así que cada fila se
    /// busca por su acción, tenga frase o no.
    func testPantallaSiri() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-almacenEnMemoria"]
        app.launch()

        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["Siri"].tap()
        XCTAssertTrue(app.navigationBars["Siri"].waitForExistence(timeout: 3))
        func fila(_ accion: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(accion), ")).firstMatch
        }
        for accion in ["Crear producto", "Añadir unidades", "Quitar unidades", "Cambiar la cantidad", "Consultar un producto", "Eliminar producto"] {
            XCTAssertTrue(fila(accion).waitForExistence(timeout: 3), accion)
        }
        XCTAssertTrue(app.staticTexts["Elige una frase para cada acción y díselo a Siri tal cual."].exists)

        // El botón de Apple que abre Atajos toma el nombre interno de la app,
        // que sale de PRODUCT_NAME: dice «InventarioCasa», todo junto. Se
        // decidió dejarlo así antes que renombrar el producto.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Atajos de'")).firstMatch.exists)

        // La hoja guarda la frase propuesta al abrirse; OK solo la cierra.
        fila("Consultar un producto").tap()
        let ok = app.buttons.matching(identifier: "addtosiri.view.named").firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: 10), "No se abre la hoja de Añadir a Siri")
        app.buttons.matching(NSPredicate(format: "identifier == 'addtosiri.view.named' AND label == 'OK'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Consultar un producto, «Cuánto queda»"].waitForExistence(timeout: 5))
    }
}
