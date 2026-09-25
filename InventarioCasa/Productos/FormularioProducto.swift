import SwiftUI
import InventarioNucleo

/// Crear un producto o editarlo.
struct FormularioProducto: View {
    enum Modo: Identifiable {
        case nuevo(categoriaId: UUID)
        case editar(Producto)

        var id: String {
            switch self {
            case .nuevo(let categoriaId): "nuevo-\(categoriaId)"
            case .editar(let producto): producto.id.uuidString
            }
        }
    }

    let modo: Modo
    @Environment(Inventario.self) private var inventario
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var cantidad = 0
    @State private var autoListaCompra = true
    @State private var umbralCompra = Limites.umbralCompraPorDefecto
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

                Section {
                    Stepper(value: $cantidad, in: Limites.cantidad) {
                        Text(Textos.Formulario.unidades(cantidad))
                    }
                }

                Section {
                    Toggle(Textos.Formulario.listaAutomatica, isOn: $autoListaCompra)
                    if autoListaCompra {
                        Stepper(value: $umbralCompra, in: Limites.umbralCompra) {
                            Text(Textos.Formulario.umbral(umbralCompra))
                        }
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
        .onAppear(perform: rellenar)
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    private var titulo: String {
        switch modo {
        case .nuevo: Textos.Titulos.nuevoProducto
        case .editar(let producto): producto.nombre
        }
    }

    private var categoriaId: UUID {
        switch modo {
        case .nuevo(let categoriaId): categoriaId
        case .editar(let producto): producto.categoriaId
        }
    }

    private func rellenar() {
        switch modo {
        case .nuevo:
            campoConFoco = true
        case .editar(let producto):
            // Al editar no se abre el teclado: casi siempre se viene a cambiar
            // las unidades, y el teclado tapa el formulario y desordena el
            // recorrido con VoiceOver (se vio en la app de Expo).
            nombre = producto.nombre
            cantidad = producto.cantidad
            autoListaCompra = producto.autoListaCompra
            umbralCompra = producto.umbralCompra
        }
    }

    private func guardar() {
        guard !Nombres.limpiar(nombre).isEmpty else { return }
        do {
            switch modo {
            case .nuevo(let categoriaId):
                let creado = try inventario.crearProducto(
                    nombre: nombre,
                    en: categoriaId,
                    cantidad: cantidad,
                    umbralCompra: umbralCompra,
                    autoListaCompra: autoListaCompra
                )
                anunciar(Textos.Anuncios.productoCreado(creado.nombre))
            case .editar(let producto):
                let guardado = try inventario.editarProducto(
                    producto.id,
                    nombre: nombre,
                    cantidad: cantidad,
                    umbralCompra: umbralCompra,
                    autoListaCompra: autoListaCompra
                )
                anunciar(Textos.Anuncios.guardado(guardado.nombre))
            }
            cerrar()
        } catch .nombre(let error) {
            let categoria = inventario.categoria(categoriaId)?.nombre ?? ""
            errorNombre = Textos.Errores.nombreProducto(error, categoria: categoria)
            if let errorNombre {
                anunciar(errorNombre)
            }
        } catch {
            errorAlGuardar = true
        }
    }
}
