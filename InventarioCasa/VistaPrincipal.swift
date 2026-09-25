import SwiftUI
import InventarioNucleo

struct VistaPrincipal: View {
    var body: some View {
        TabView {
            VistaCategorias()
                .tabItem { Label(Textos.Pestanas.inventario, systemImage: "shippingbox") }
            VistaListaCompra()
                .tabItem { Label(Textos.Pestanas.compra, systemImage: "cart") }
            VistaAjustes()
                .tabItem { Label(Textos.Pestanas.ajustes, systemImage: "gearshape") }
        }
    }
}
