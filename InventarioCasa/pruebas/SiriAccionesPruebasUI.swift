import AppIntentsTesting
import XCTest

/// Las acciones de Siri ejecutadas como las ejecuta Siri (AppIntentsTesting,
/// fuera del proceso de la prueba, contra la app instalada), sin voz: el
/// simulador no reconoce frases (ver CLAUDE.md). La app se abre antes con los
/// datos de ejemplo y las acciones corren dentro de ese proceso; el efecto se
/// comprueba en la pantalla.
@available(iOS 27.0, *)
@MainActor
final class SiriAccionesPruebasUI: XCTestCase {
    private let app = XCUIApplication()
    private let definiciones = IntentDefinitions(bundleIdentifier: "com.jmortiz.inventario")

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchArguments = ["-datosDeEjemplo"]
        app.launch()
        app.buttons["Despensa, 2 productos"].tap()
        XCTAssertTrue(app.buttons["Arroz, 3 unidades"].waitForExistence(timeout: 5))
    }

    private func producto(_ dicho: String) async throws -> AnyAppEntity {
        let encontrados = try await definiciones.entities["ProductoEntidad"].entities(matching: dicho)
        XCTAssertEqual(encontrados.count, 1, "«\(dicho)» tendría que encontrar un producto")
        return try XCTUnwrap(encontrados.first)
    }

    private func esperar(_ fila: String) {
        XCTAssertTrue(app.buttons[fila].waitForExistence(timeout: 5), "No aparece «\(fila)»")
    }

    func testBuscarProductoComoLoDiceSiri() async throws {
        let productos = definiciones.entities["ProductoEntidad"]
        let mayusculas = try await productos.entities(matching: "ARROZ")
        let plural = try await productos.entities(matching: "leches")
        let ninguno = try await productos.entities(matching: "huevos")
        let sugeridos = try await productos.suggestedEntities()
        XCTAssertEqual(mayusculas.count, 1)
        XCTAssertEqual(plural.count, 1, "Plural de Leche")
        XCTAssertEqual(ninguno.count, 0)
        XCTAssertEqual(sugeridos.count, 3)
    }

    func testAnadirQuitarYCambiarUnidades() async throws {
        let arroz = try await producto("arroz")
        try await definiciones.intents["AnadirUnidades"].makeIntent(producto: arroz, unidades: 2).run()
        esperar("Arroz, 5 unidades")
        try await definiciones.intents["QuitarUnidades"].makeIntent(producto: arroz, unidades: 1).run()
        esperar("Arroz, 4 unidades")
        try await definiciones.intents["CambiarCantidad"].makeIntent(producto: arroz, unidades: 7).run()
        esperar("Arroz, 7 unidades")
        try await definiciones.intents["ConsultarProducto"].makeIntent(producto: arroz).run()
    }

    func testCrearYEliminarProducto() async throws {
        // La categoría se dice de viva voz: sin mayúsculas ni tildes.
        try await definiciones.intents["CrearProducto"]
            .makeIntent(nombre: "Garbanzos", categoria: "despensa", unidades: 2).run()
        // Con 2 unidades llega al mínimo por defecto y entra en la lista.
        esperar("Garbanzos, 2 unidades, en la lista")

        let garbanzos = try await producto("garbanzos")
        // La confirmación la contesta AppIntentsTesting sola.
        try await definiciones.intents["EliminarProducto"].makeIntent(producto: garbanzos).run()
        XCTAssertTrue(app.buttons["Garbanzos, 2 unidades, en la lista"].waitForNonExistence(timeout: 5))
    }

    func testCrearEnUnaCategoriaQueNoExiste() async throws {
        do {
            try await definiciones.intents["CrearProducto"]
                .makeIntent(nombre: "Pilas", categoria: "trastero", unidades: 1).run()
            XCTFail("Tendría que fallar: no hay categoría Trastero")
        } catch {
            // Siri dice «No encuentro trastero.»
        }
    }
}
