import SwiftUI
import InventarioNucleo

struct VistaListaCompra: View {
    @Environment(Inventario.self) private var inventario
    @State private var formulario: FormularioProducto.Modo?
    @State private var errorAlGuardar = false

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle(Textos.Titulos.listaCompra)
        }
        .sheet(item: $formulario) { modo in
            FormularioProducto(modo: modo)
        }
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    @ViewBuilder
    private var contenido: some View {
        let lista = inventario.listaCompra
        if lista.isEmpty {
            ContentUnavailableView(Textos.Vacio.listaCompra, systemImage: "checkmark.circle")
        } else {
            List {
                Section {
                    ForEach(lista) { producto in
                        fila(producto)
                    }
                } header: {
                    Text(Textos.productos(lista.count))
                }
            }
        }
    }

    private func fila(_ producto: Producto) -> some View {
        let categoria = inventario.categoria(producto.categoriaId)?.nombre ?? ""
        return FilaProducto(
            producto: producto,
            etiqueta: Textos.filaCompra(producto, categoria: categoria),
            alEditar: { formulario = .editar(producto) },
            alAjustar: { errorAlGuardar = !inventario.ajustarYAnunciar(producto, en: $0) }
        ) {
            HStack(spacing: 4) {
                if producto.cantidad == 0 {
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

    private func quitar(_ producto: Producto) {
        errorAlGuardar = !inventario.cambiarListaYAnunciar(producto)
    }
}

#Preview {
    VistaListaCompra()
        .environment(VistaPrevia.inventario())
}
