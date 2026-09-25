import SwiftUI
import InventarioNucleo
import InventarioAlmacen

/// Abre el almacén y, si no se puede leer, lo dice y deja reintentar.
struct VistaRaiz: View {
    @State private var inventario: Inventario?
    @State private var falloAlAbrir = false

    var body: some View {
        Group {
            if let inventario {
                VistaCategorias()
                    .environment(inventario)
            } else if falloAlAbrir {
                ContentUnavailableView {
                    Label(Textos.Errores.noLeido, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(Textos.Botones.reintentar, action: abrir)
                }
            }
        }
        .onAppear(perform: abrir)
    }

    private func abrir() {
        guard inventario == nil else { return }
        #if DEBUG
        // Para capturas y pruebas a mano: datos de ejemplo en memoria, sin tocar los guardados.
        if ProcessInfo.processInfo.arguments.contains("-datosDeEjemplo") {
            inventario = VistaPrevia.inventario()
            return
        }
        #endif
        do {
            let nuevo = Inventario(almacen: try AlmacenSwiftData.enDisco())
            try nuevo.cargar()
            inventario = nuevo
            falloAlAbrir = false
        } catch {
            falloAlAbrir = true
        }
    }
}
