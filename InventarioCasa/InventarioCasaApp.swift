import AppIntents
import SwiftUI

@main
struct InventarioCasaApp: App {
    @UIApplicationDelegateAdaptor(DelegadoApp.self) private var delegado

    init() {
        // Aquí y no en una vista: con Siri, iOS arranca la app sin crear ninguna.
        let arranque = Arranque.compartido
        AppDependencyManager.shared.add(dependency: arranque)
    }

    var body: some Scene {
        WindowGroup {
            VistaRaiz()
        }
    }
}
