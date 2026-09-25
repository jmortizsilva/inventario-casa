import SwiftUI
import InventarioNucleo

struct VistaProductos: View {
    let categoriaId: UUID
    @Environment(Inventario.self) private var inventario
    @State private var formulario: FormularioProducto.Modo?
    @State private var aEliminar: Producto?
    @State private var errorAlGuardar = false

    private var nombreCategoria: String {
        inventario.categoria(categoriaId)?.nombre ?? ""
    }

    var body: some View {
        contenido
            .navigationTitle(nombreCategoria)
            .toolbar {
                Button {
                    formulario = .nuevo(categoriaId: categoriaId)
                } label: {
                    Label(Textos.Botones.anadirProducto, systemImage: "plus")
                }
            }
            .sheet(item: $formulario) { modo in
                FormularioProducto(modo: modo)
            }
            .alert(
                aEliminar.map { Textos.Confirmacion.eliminar($0.nombre) } ?? "",
                isPresented: Binding(get: { aEliminar != nil }, set: { if !$0 { aEliminar = nil } }),
                presenting: aEliminar
            ) { producto in
                Button(Textos.Botones.eliminar, role: .destructive) { eliminar(producto) }
                Button(Textos.Botones.cancelar, role: .cancel) {}
            }
            .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    @ViewBuilder
    private var contenido: some View {
        let productos = inventario.productos(en: categoriaId)
        if productos.isEmpty {
            ContentUnavailableView {
                Label(Textos.Vacio.productos(en: nombreCategoria), systemImage: "shippingbox")
            } actions: {
                Button(Textos.Botones.anadirProducto) {
                    formulario = .nuevo(categoriaId: categoriaId)
                }
            }
        } else {
            List(productos) { producto in
                fila(producto)
            }
        }
    }

    private func fila(_ producto: Producto) -> some View {
        FilaProducto(
            producto: producto,
            etiqueta: Textos.filaProducto(producto),
            alEditar: { formulario = .editar(producto) },
            alAjustar: { errorAlGuardar = !inventario.ajustarYAnunciar(producto, en: $0) }
        ) {
            HStack(spacing: 4) {
                Text(Textos.unidades(producto.cantidad))
                if ListaCompra.incluye(producto) {
                    Image(systemName: "cart")
                }
            }
        }
        .accessibilityAction(named: textoLista(producto)) { cambiarLista(producto) }
        .accessibilityAction(named: Textos.Botones.eliminar) { aEliminar = producto }
        .contextMenu {
            Button(textoLista(producto), systemImage: producto.enListaCompraManual ? "cart.badge.minus" : "cart.badge.plus") {
                cambiarLista(producto)
            }
            Button(Textos.Botones.eliminar, systemImage: "trash", role: .destructive) {
                aEliminar = producto
            }
        }
    }

    private func textoLista(_ producto: Producto) -> String {
        producto.enListaCompraManual ? Textos.Botones.quitarDeLista : Textos.Botones.anadirALista
    }

    private func cambiarLista(_ producto: Producto) {
        errorAlGuardar = !inventario.cambiarListaYAnunciar(producto)
    }

    private func eliminar(_ producto: Producto) {
        errorAlGuardar = !inventario.eliminarYAnunciar(producto)
    }
}

#Preview {
    let inventario = VistaPrevia.inventario()
    return NavigationStack {
        VistaProductos(categoriaId: inventario.categorias[0].id)
    }
    .environment(inventario)
}
