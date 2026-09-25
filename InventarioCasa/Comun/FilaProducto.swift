import SwiftUI
import InventarioNucleo

/// Fila de producto con botones de menos y más. Para VoiceOver es un solo
/// elemento: activarla edita, y aumentar y disminuir son acciones del rotor.
/// Quien la usa añade detrás las acciones propias de su pantalla.
struct FilaProducto<Detalle: View>: View {
    let producto: Producto
    let etiqueta: String
    let alEditar: () -> Void
    let alAjustar: (Int) -> Void
    @ViewBuilder let detalle: Detalle

    var body: some View {
        HStack(spacing: 12) {
            // Toque y no botón: un botón aquí dentro sería otro elemento con la
            // misma etiqueta que la fila. VoiceOver edita con la acción por defecto.
            VStack(alignment: .leading, spacing: 2) {
                Text(producto.nombre)
                detalle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: alEditar)

            Button {
                alAjustar(-1)
            } label: {
                botonCantidad(Textos.Botones.disminuirCantidad, simbolo: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(producto.cantidad == Limites.cantidad.lowerBound)

            Button {
                alAjustar(1)
            } label: {
                botonCantidad(Textos.Botones.aumentarCantidad, simbolo: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(producto.cantidad == Limites.cantidad.upperBound)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiqueta)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { alEditar() }
        .accessibilityAction(named: Textos.Botones.aumentarCantidad) { alAjustar(1) }
        .accessibilityAction(named: Textos.Botones.disminuirCantidad) { alAjustar(-1) }
    }

    /// El marco va dentro de la etiqueta: puesto por fuera del botón no amplía
    /// la zona que responde al toque, y el signo menos se quedaba en 23 × 5 puntos.
    private func botonCantidad(_ texto: String, simbolo: String) -> some View {
        Label(texto, systemImage: simbolo)
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
