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
        let enLista = ListaCompra.incluye(producto)
        return HStack(spacing: 12) {
            // Toque y no botón: un botón aquí dentro sería otro elemento con la
            // misma etiqueta que la fila. VoiceOver edita con la acción por defecto.
            VStack(alignment: .leading, spacing: 2) {
                Text(producto.nombre)
                HStack(spacing: 4) {
                    Text(Textos.unidades(producto.cantidad))
                    if enLista {
                        Image(systemName: "cart")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { formulario = .editar(producto) }

            // Sin estilo sin borde, la lista trata toda la fila como un botón y
            // cualquier toque abriría la edición.
            Button {
                ajustar(producto, en: -1)
            } label: {
                botonCantidad(Textos.Botones.disminuirCantidad, simbolo: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(producto.cantidad == Limites.cantidad.lowerBound)

            Button {
                ajustar(producto, en: 1)
            } label: {
                botonCantidad(Textos.Botones.aumentarCantidad, simbolo: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(producto.cantidad == Limites.cantidad.upperBound)
        }
        // Un solo elemento para VoiceOver: los botones de la fila se sustituyen
        // por las acciones del rotor.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Textos.filaProducto(producto))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { formulario = .editar(producto) }
        .accessibilityAction(named: Textos.Botones.aumentarCantidad) { ajustar(producto, en: 1) }
        .accessibilityAction(named: Textos.Botones.disminuirCantidad) { ajustar(producto, en: -1) }
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

    /// El marco va dentro de la etiqueta: puesto por fuera del botón no amplía
    /// la zona que responde al toque, y el signo menos se quedaba en 23 × 5 puntos.
    private func botonCantidad(_ texto: String, simbolo: String) -> some View {
        Label(texto, systemImage: simbolo)
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private func textoLista(_ producto: Producto) -> String {
        producto.enListaCompraManual ? Textos.Botones.quitarDeLista : Textos.Botones.anadirALista
    }

    private func ajustar(_ producto: Producto, en cambio: Int) {
        do {
            let despues = try inventario.ajustarCantidad(producto.id, en: cambio)
            anunciar(Textos.Anuncios.ajusteCantidad(antes: producto, despues: despues, cambio: cambio))
        } catch {
            errorAlGuardar = true
        }
    }

    private func cambiarLista(_ producto: Producto) {
        do {
            let despues = try inventario.fijarListaManual(producto.id, en: !producto.enListaCompraManual)
            anunciar(Textos.Anuncios.listaManual(despues: despues))
        } catch {
            errorAlGuardar = true
        }
    }

    private func eliminar(_ producto: Producto) {
        do {
            try inventario.borrarProducto(producto.id)
            anunciar(Textos.Anuncios.productoEliminado(producto.nombre))
        } catch {
            errorAlGuardar = true
        }
    }
}

#Preview {
    let inventario = VistaPrevia.inventario()
    return NavigationStack {
        VistaProductos(categoriaId: inventario.categorias[0].id)
    }
    .environment(inventario)
}
