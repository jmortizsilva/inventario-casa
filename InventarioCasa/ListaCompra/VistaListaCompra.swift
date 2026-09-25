import SwiftUI
import InventarioNucleo

struct VistaListaCompra: View {
    @Environment(Inventario.self) private var inventario
    @State private var formulario: FormularioProducto.Modo?
    @State private var errorAlGuardar = false
    /// Orden de las filas durante la visita a la pestaña. Lo que sale de la lista
    /// al reponerlo sigue aquí, marcado como repuesto, para poder seguir sumando
    /// unidades sin que la fila desaparezca ni el foco de VoiceOver salte. Se
    /// olvida al salir de la pestaña.
    @State private var orden: [UUID] = []

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle(Textos.Titulos.listaCompra)
        }
        .onAppear { orden = inventario.listaCompra.map(\.id) }
        .onDisappear { orden = [] }
        .sheet(item: $formulario) { modo in
            FormularioProducto(modo: modo)
        }
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    /// Lo de la visita en su orden y, detrás, lo que haya entrado después.
    private var filas: [Producto] {
        var ids = orden
        for producto in inventario.listaCompra where !ids.contains(producto.id) {
            ids.append(producto.id)
        }
        return ids.compactMap { inventario.producto($0) }
    }

    @ViewBuilder
    private var contenido: some View {
        let filas = filas
        if filas.isEmpty {
            ContentUnavailableView(Textos.Vacio.listaCompra, systemImage: "checkmark.circle")
        } else {
            List {
                Section {
                    ForEach(filas) { producto in
                        fila(producto)
                    }
                } header: {
                    Text(Textos.productos(filas.filter(ListaCompra.incluye).count))
                }
            }
        }
    }

    private func fila(_ producto: Producto) -> some View {
        let categoria = inventario.categoria(producto.categoriaId)?.nombre ?? ""
        let repuesto = !ListaCompra.incluye(producto)
        return FilaProducto(
            producto: producto,
            etiqueta: Textos.filaCompra(producto, categoria: categoria, repuesto: repuesto),
            alEditar: { formulario = .editar(producto) },
            alAjustar: { ajustar(producto, en: $0) }
        ) {
            HStack(spacing: 4) {
                if repuesto {
                    Label(Textos.repuesto, systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                    Text("·")
                    Text(Textos.unidades(producto.cantidad))
                } else if producto.cantidad == 0 {
                    Text(Textos.agotado)
                        .bold()
                        .foregroundStyle(.red)
                } else {
                    Text(Textos.unidades(producto.cantidad))
                }
                Text("·")
                Text(categoria)
                if producto.enListaCompraManual {
                    Image(systemName: "cart.badge.plus")
                }
            }
        }
        // Quitar solo tiene sentido si se añadió a mano: si está por tener pocas
        // unidades, sale al reponerlo.
        .accessibilityActions {
            if producto.enListaCompraManual {
                Button(Textos.Botones.quitarDeLista) { quitar(producto) }
            }
        }
        .contextMenu {
            if producto.enListaCompraManual {
                Button(Textos.Botones.quitarDeLista, systemImage: "cart.badge.minus") {
                    quitar(producto)
                }
            }
        }
    }

    private func ajustar(_ producto: Producto, en cambio: Int) {
        // Si entró en la lista durante la visita, se fija su sitio para que
        // tampoco desaparezca al reponerlo.
        if !orden.contains(producto.id) {
            orden.append(producto.id)
        }
        errorAlGuardar = !inventario.ajustarYAnunciar(producto, en: cambio)
    }

    /// Quitar a mano sí lo saca de la vista: no es que se haya repuesto.
    private func quitar(_ producto: Producto) {
        if inventario.cambiarListaYAnunciar(producto) {
            if let despues = inventario.producto(producto.id), !ListaCompra.incluye(despues) {
                orden.removeAll { $0 == producto.id }
            }
        } else {
            errorAlGuardar = true
        }
    }
}

#Preview {
    VistaListaCompra()
        .environment(VistaPrevia.inventario())
}
