import SwiftUI
import InventarioNucleo

struct VistaCategorias: View {
    @Environment(Inventario.self) private var inventario
    @State private var formulario: FormularioCategoria.Modo?
    @State private var aEliminar: Categoria?
    @State private var errorAlGuardar = false

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle(Textos.Titulos.inventario)
                .navigationDestination(for: UUID.self) { id in
                    VistaProductos(categoriaId: id)
                }
                .toolbar {
                    Button {
                        formulario = .nueva
                    } label: {
                        Label(Textos.Botones.anadirCategoria, systemImage: "plus")
                    }
                }
        }
        .sheet(item: $formulario) { modo in
            FormularioCategoria(modo: modo)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Textos.filaCategoria(categoria, productos: productos))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Textos.Botones.cambiarNombre) {
            formulario = .renombrar(categoria)
        }
        .accessibilityAction(named: Textos.Botones.eliminar) {
            aEliminar = categoria
        }
        .contextMenu {
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
