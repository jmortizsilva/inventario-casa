import XCTest

/// Importa desde el selector de archivos del sistema. Los archivos se escriben
/// en «En mi iPhone» del simulador antes de cada prueba: el proceso de pruebas
/// corre en el Mac y puede escribir en la carpeta del simulador.
@MainActor
final class ImportarPruebasUI: XCTestCase {
    private var app: XCUIApplication!
    private var carpeta: URL!

    private static let exportacion = """
    {"formato":"inventario-casa","version":1,
     "categorias":[{"id":"11111111-0000-0000-0000-000000000001","nombre":"Despensa","creado":"2025-03-01T10:00:00Z","modificado":"2025-03-01T10:00:00Z"}],
     "productos":[
      {"id":"22222222-0000-0000-0000-000000000001","categoriaId":"11111111-0000-0000-0000-000000000001","nombre":"Arroz","cantidad":3,"umbralCompra":2,"autoListaCompra":true,"enListaCompraManual":false,"creado":"2025-03-01T10:00:00Z","modificado":"2025-03-01T10:00:00Z"},
      {"id":"22222222-0000-0000-0000-000000000002","categoriaId":"11111111-0000-0000-0000-000000000001","nombre":"Aceite","cantidad":0,"umbralCompra":2,"autoListaCompra":true,"enListaCompraManual":false,"creado":"2025-03-01T10:00:00Z","modificado":"2025-03-01T10:00:00Z"}
     ]}
    """

    override func setUp() async throws {
        continueAfterFailure = false
        carpeta = try XCTUnwrap(Self.carpetaEnMiIPhone(), "No se encuentra «En mi iPhone» en el simulador")
        try Data(Self.exportacion.utf8).write(to: carpeta.appendingPathComponent("prueba-inventario.json"))
        try Data("{}".utf8).write(to: carpeta.appendingPathComponent("prueba-no-valido.json"))
        app = XCUIApplication()
        app.launchArguments = ["-almacenEnMemoria"]
        app.launch()
    }

    override func tearDown() async throws {
        for nombre in ["prueba-inventario.json", "prueba-no-valido.json"] {
            try? FileManager.default.removeItem(at: carpeta.appendingPathComponent(nombre))
        }
    }

    /// La carpeta de «En mi iPhone» es el grupo de apps
    /// group.com.apple.FileProvider.LocalStorage del simulador.
    private static func carpetaEnMiIPhone() -> URL? {
        guard let datos = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"] else { return nil }
        let grupos = URL(fileURLWithPath: datos).appendingPathComponent("Containers/Shared/AppGroup")
        let contenido = (try? FileManager.default.contentsOfDirectory(at: grupos, includingPropertiesForKeys: nil)) ?? []
        for grupo in contenido {
            let metadatos = grupo.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let plist = NSDictionary(contentsOf: metadatos),
               plist["MCMMetadataIdentifier"] as? String == "group.com.apple.FileProvider.LocalStorage" {
                return grupo.appendingPathComponent("File Provider Storage")
            }
        }
        return nil
    }

    private func importar(_ archivo: String) {
        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["Importar datos"].tap()
        // Hay dos «Explorar»: la pestaña y, si ya se entró en una carpeta, el botón
        // para volver. Cualquiera de los dos lleva a la lista de ubicaciones.
        let explorar = app.buttons["Explorar"].firstMatch
        XCTAssertTrue(explorar.waitForExistence(timeout: 5))
        explorar.tap()
        // Explorar puede abrirse ya dentro de la última carpeta visitada.
        let enMiIPhone = app.cells.staticTexts["En mi iPhone"]
        if enMiIPhone.waitForExistence(timeout: 2) {
            enMiIPhone.tap()
        }
        // El selector muestra el nombre con la extensión.
        let celda = app.cells.containing(.staticText, identifier: archivo).firstMatch
        XCTAssertTrue(celda.waitForExistence(timeout: 5), "No aparece \(archivo)")
        celda.tap()
    }

    private func aceptar(_ titulo: String, mensaje: String? = nil) {
        let alerta = app.alerts[titulo]
        XCTAssertTrue(alerta.waitForExistence(timeout: 5), "No aparece la alerta «\(titulo)»")
        if let mensaje {
            XCTAssertTrue(alerta.staticTexts[mensaje].exists, mensaje)
        }
        alerta.buttons["Aceptar"].tap()
    }

    func testImportarYRepetir() {
        importar("prueba-inventario.json")
        aceptar("Importada 1 categoría y 2 productos")

        app.tabBars.buttons["Inventario"].tap()
        XCTAssertTrue(app.buttons["Despensa, 2 productos"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Compra"].tap()
        XCTAssertTrue(app.buttons["Aceite, agotado, Despensa"].waitForExistence(timeout: 3))

        importar("prueba-inventario.json")
        aceptar("No había nada nuevo que importar", mensaje: "2 ya estaban.")
    }

    func testArchivoNoValido() {
        importar("prueba-no-valido.json")
        aceptar("No se ha importado", mensaje: "El archivo no es una exportación del inventario.")
    }
}
