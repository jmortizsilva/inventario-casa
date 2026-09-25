import SwiftUI
import InventarioNucleo

struct VistaCategorias: View {
    @Environment(Inventario.self) private var inventario
    @State private var formulario: FormularioCategoria.Modo?
    @State private var nuevoProducto: FormularioProducto.Modo?
    @State private var aEliminar: Categoria?
    @State private var errorAlGuardar = false

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle(Textos.Titulos.inventario)
                // Con el título grande, VoiceOver leía antes el botón de la barra que
                // el título, porque el título se dibuja debajo. En la barra va primero.
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: UUID.self) { id in
                    VistaProductos(categoriaId: id)
                }
                .toolbar {
                    Menu {
                        Button(Textos.Botones.categoria) { formulario = .nueva }
                        Button(Textos.Botones.producto) { nuevoProducto = .nuevo(categoriaId: nil) }
                            .disabled(inventario.categorias.isEmpty)
                    } label: {
                        Label(Textos.Botones.anadir, systemImage: "plus")
                    }
                    // VoiceOver lo leía como un botón más. No hay rasgo público para
                    // «abre un menú»: «botón desplegable» es para los selectores de
                    // un valor, y un UIButton con menú de acciones se oye igual que
                    // este. Por eso lo dice el nombre.
                    .accessibilityLabel(Textos.Botones.anadirMenu)
                }
        }
        .sheet(item: $formulario) { modo in
            FormularioCategoria(modo: modo)
        }
        .sheet(item: $nuevoProducto) { modo in
            FormularioProducto(modo: modo)
        }
        .alert(
            aEliminar.map { Textos.Confirmacion.eliminar($0.nombre) } ?? "",
            isPresented: Binding(get: { aEliminar != nil }, set: { if !$0 { aEliminar = nil } }),
            presenting: aEliminar
        ) { categoria in
            Button(Textos.Botones.eliminar, role: .destructive) { eliminar(categoria) }
            Button(Textos.Botones.cancelar, role: .cancel) {}
        } message: { categoria in
            if let mensaje = Textos.Confirmacion.eliminarCategoria(productos: numeroProductos(categoria)) {
                Text(mensaje)
            }
        }
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    @ViewBuilder
    private var contenido: some View {
        if inventario.categorias.isEmpty {
            ContentUnavailableView {
                Label(Textos.Vacio.categorias, systemImage: "shippingbox")
            } actions: {
                Button(Textos.Botones.anadirCategoria) { formulario = .nueva }
            }
        } else {
            List(inventario.categorias) { categoria in
                fila(categoria)
            }
        }
    }

    private func fila(_ categoria: Categoria) -> some View {
        let productos = numeroProductos(categoria)
        return NavigationLink(value: categoria.id) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoria.nombre)
                Text(Textos.productos(productos))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        // Solo la etiqueta: el NavigationLink ya junta sus textos en un botón.
        // Con .accessibilityElement(children: .ignore) aparecía un segundo botón
        // anidado con la misma etiqueta.
        .accessibilityLabel(Textos.filaCategoria(categoria, productos: productos))
        .accessibilityAction(named: Textos.Botones.anadirProducto) {
            nuevoProducto = .nuevo(categoriaId: categoria.id)
        }
        .accessibilityAction(named: Textos.Botones.cambiarNombre) {
            formulario = .renombrar(categoria)
        }
        .accessibilityAction(named: Textos.Botones.eliminar) {
            aEliminar = categoria
        }
        .contextMenu {
            Button(Textos.Botones.anadirProducto, systemImage: "plus") {
                nuevoProducto = .nuevo(categoriaId: categoria.id)
            }
            Button(Textos.Botones.cambiarNombre, systemImage: "pencil") {
                formulario = .renombrar(categoria)
            }
            Button(Textos.Botones.eliminar, systemImage: "trash", role: .destructive) {
                aEliminar = categoria
            }
        }
    }

    private func numeroProductos(_ categoria: Categoria) -> Int {
        inventario.productos(en: categoria.id).count
    }

    private func eliminar(_ categoria: Categoria) {
        let productos = numeroProductos(categoria)
        do {
            try inventario.borrarCategoria(categoria.id)
            anunciar(Textos.Anuncios.categoriaEliminada(categoria.nombre, productos: productos))
        } catch {
            errorAlGuardar = true
        }
    }
}

#Preview("Con categorías") {
    VistaCategorias()
        .environment(VistaPrevia.inventario())
}

#Preview("Vacía") {
    VistaCategorias()
        .environment(VistaPrevia.inventario(vacio: true))
}
