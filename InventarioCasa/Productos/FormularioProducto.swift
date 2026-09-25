import SwiftUI
import InventarioNucleo

/// Crear un producto o editarlo.
struct FormularioProducto: View {
    enum Modo: Identifiable {
        /// Sin categoría (desde el menú Añadir de Inventario) se elige en el formulario.
        case nuevo(categoriaId: UUID?)
        case editar(Producto)

        var id: String {
            switch self {
            case .nuevo(let categoriaId): "nuevo-\(categoriaId?.uuidString ?? "sin-categoria")"
            case .editar(let producto): producto.id.uuidString
            }
        }
    }

    let modo: Modo
    @Environment(Inventario.self) private var inventario
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var categoriaElegida: UUID?
    @State private var cantidad = 0
    @State private var autoListaCompra = true
    @State private var umbralCompra = Limites.umbralCompraPorDefecto
    @State private var errorNombre: String?
    @State private var errorAlGuardar = false
    @FocusState private var campoConFoco: Bool

    var body: some View {
        NavigationStack {
            Form {
                // Si hay que elegir categoría, va primero y sin teclado abierto: con
                // el teclado a la vista, VoiceOver pasaba del menú del selector al
                // teclado que quedaba detrás.
                if pideCategoria {
                    Section {
                        selectorCategoria
                    }
                }

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
                    selector(
                        visible: Textos.Formulario.unidades(cantidad),
                        etiqueta: Textos.Formulario.etiquetaUnidades,
                        valor: Textos.Formulario.valorUnidades(cantidad),
                        numero: $cantidad,
                        rango: Limites.cantidad
                    )
                }

                Section {
                    Toggle(Textos.Formulario.listaAutomatica, isOn: $autoListaCompra)
                    if autoListaCompra {
                        selector(
                            visible: Textos.Formulario.umbral(umbralCompra),
                            etiqueta: Textos.Formulario.etiquetaUmbral,
                            valor: Textos.Formulario.valorUmbral(umbralCompra),
                            numero: $umbralCompra,
                            rango: Limites.umbralCompra
                        )
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
                        .disabled(Nombres.limpiar(nombre).isEmpty || categoriaId == nil)
                }
            }
            .onChange(of: nombre) { errorNombre = nil }
        }
        .onAppear(perform: rellenar)
        .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    /// Fila con un Stepper a la vista que, para VoiceOver, es un único elemento
    /// ajustable (deslizar arriba o abajo) con etiqueta y valor propios.
    /// El Stepper del sistema exponía sus dos botones por separado, y ponerle
    /// .accessibilityLabel no sustituía la etiqueta de su texto sino que la
    /// añadía detrás («Unidades: 3, Unidades»).
    private func selector(
        visible: String,
        etiqueta: String,
        valor: String,
        numero: Binding<Int>,
        rango: ClosedRange<Int>
    ) -> some View {
        HStack {
            Text(visible)
            Spacer()
            Stepper(etiqueta, value: numero, in: rango)
                .labelsHidden()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiqueta)
        .accessibilityValue(valor)
        .accessibilityAdjustableAction { direccion in
            switch direccion {
            case .increment: numero.wrappedValue = rango.acotar(numero.wrappedValue + 1)
            case .decrement: numero.wrappedValue = rango.acotar(numero.wrappedValue - 1)
            @unknown default: break
            }
        }
    }

    private var titulo: String {
        switch modo {
        case .nuevo: Textos.Titulos.nuevoProducto
        case .editar(let producto): producto.nombre
        }
    }

    /// Sin valor hasta elegir. Nada de opción «Elegir» con valor nulo: salía en
    /// el menú como una categoría más, marcada como elegida.
    private var selectorCategoria: some View {
        Picker(Textos.Formulario.categoria, selection: $categoriaElegida) {
            ForEach(inventario.categorias) { categoria in
                Text(categoria.nombre).tag(UUID?.some(categoria.id))
            }
        }
    }

    private var pideCategoria: Bool {
        if case .nuevo(nil) = modo { true } else { false }
    }

    private var categoriaId: UUID? {
        switch modo {
        case .nuevo: categoriaElegida
        case .editar(let producto): producto.categoriaId
        }
    }

    private func rellenar() {
        switch modo {
        case .nuevo(let categoriaId):
            categoriaElegida = categoriaId
            // Con categoría por elegir, el teclado esperaría a que se toque el nombre.
            campoConFoco = categoriaId != nil
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
        guard !Nombres.limpiar(nombre).isEmpty, let categoriaId else { return }
        do {
            switch modo {
            case .nuevo:
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

private extension ClosedRange where Bound == Int {
    func acotar(_ valor: Int) -> Int { Swift.min(Swift.max(valor, lowerBound), upperBound) }
}
