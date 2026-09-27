import SwiftUI

@main
struct InventarioCasaApp: App {
    @UIApplicationDelegateAdaptor(DelegadoApp.self) private var delegado

    var body: some Scene {
        WindowGroup {
            VistaRaiz()
        }
    }
}
