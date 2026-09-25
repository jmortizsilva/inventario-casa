import SwiftUI
import InventarioNucleo

/// Crear una categoría o cambiarle el nombre.
struct FormularioCategoria: View {
    enum Modo: Identifiable {
        case nueva
        case renombrar(Categoria)

        var id: String {
            switch self {
            case .nueva: "nueva"
            case .renombrar(let categoria): categoria.id.uuidString
            }
        }
    }

    let modo: Modo
    @Environment(Inventario.self) private var inventario
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var errorNombre: String?
    @State private var errorAlGuardar = false
    @FocusState private var campoConFoco: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Textos.Formulario.nombre, text: $nombre)
                        .focused($campoConFoco)
                        .submitLabel(.done)
                        .onSubmit(guardar)
                } footer: {
                    if let errorNombre {
                        Text(errorNombre)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.Botones.cancelar) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.Botones.guardar, action: guardar)
                        .disabled(Nombres.limpiar(nombre).isEmpty)
                }
            }
            .onChange(of: nombre) { errorNombre = nil }
        }
        .onAppear {
            if case .renombrar(let categoria) = modo {
                nombre = categoria.nombre
            }
            campoConFoco = true
        }
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    private var titulo: String {
        switch modo {
        case .nueva: Textos.Titulos.nuevaCategoria
        case .renombrar: Textos.Titulos.cambiarNombre
        }
    }

    private func guardar() {
        guard !Nombres.limpiar(nombre).isEmpty else { return }
        do {
            switch modo {
            case .nueva:
                let creada = try inventario.crearCategoria(nombre: nombre)
                anunciar(Textos.Anuncios.categoriaCreada(creada.nombre))
            case .renombrar(let categoria):
                let guardada = try inventario.renombrarCategoria(categoria.id, a: nombre)
                anunciar(Textos.Anuncios.guardado(guardada.nombre))
            }
            cerrar()
        } catch .nombre(let error) {
            errorNombre = Textos.Errores.nombreCategoria(error)
            if let errorNombre {
                anunciar(errorNombre)
            }
        } catch {
            errorAlGuardar = true
        }
    }
}
