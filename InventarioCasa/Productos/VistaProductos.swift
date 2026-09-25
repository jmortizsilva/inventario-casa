import SwiftUI
import InventarioNucleo

/// Provisional: la lista de productos llega en el siguiente paso de la fase 4.
struct VistaProductos: View {
    let categoriaId: UUID
    @Environment(Inventario.self) private var inventario

    var body: some View {
        let nombre = inventario.categoria(categoriaId)?.nombre ?? ""
        ContentUnavailableView(Textos.Vacio.productos(en: nombre), systemImage: "shippingbox")
            .navigationTitle(nombre)
    }
}
