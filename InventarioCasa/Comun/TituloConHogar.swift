import InventarioNucleo
import SwiftUI

extension View {
    /// «Inventario - Casa» con hogar, «Inventario» sin él.
    func tituloConHogar(_ pantalla: String) -> some View {
        modifier(TituloConHogar(pantalla: pantalla))
    }
}

/// El título en el centro de la barra, en una vista propia: el de la barra
/// se corta con «…» en una línea, y «Lista de la compra - Casa de Luis» no
/// cabe. Este pasa a dos líneas solo cuando no cabe. `navigationTitle` se
/// deja igual, para el botón de volver y el selector de apps.
private struct TituloConHogar: ViewModifier {
    @Environment(Cuenta.self) private var cuenta
    let pantalla: String

    func body(content: Content) -> some View {
        let titulo = Textos.titulo(pantalla, hogar: cuenta.nombreDelHogar)
        content
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(titulo)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
