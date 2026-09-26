import InventarioConexion
import InventarioNucleo
import SwiftUI

/// Tras iniciar sesión sin hogar: crear uno o unirse al de otra persona. En
/// la bienvenida va dentro de su propia navegación; en Ajustes, en una hoja.
struct VistaTuHogar: View {
    @Environment(Cuenta.self) private var cuenta
    var alTerminar: () -> Void

    var body: some View {
        Form {
            Section {
                Text(Textos.Hogar.explicacion)
            }
            Section {
                NavigationLink(Textos.Hogar.crear) {
                    FormularioCrearHogar(alTerminar: alTerminar)
                }
                NavigationLink(Textos.Hogar.unirmeConCodigo) {
                    FormularioUnirse(alTerminar: alTerminar)
                }
                Button(Textos.Hogar.ahoraNo) {
                    cuenta.pedirHogar = false
                    alTerminar()
                }
            }
        }
        .navigationTitle(Textos.Hogar.tituloElegir)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// «Tu nombre» solo si la cuenta no tiene: con Apple, que no lo da.
private struct CampoTuNombre: View {
    @Binding var nombre: String

    var body: some View {
        TextField(Textos.Hogar.campoTuNombre, text: $nombre)
            .textContentType(.name)
            .accessibilityHint(Textos.Hogar.pistaTuNombre)
    }
}

struct FormularioCrearHogar: View {
    @Environment(Cuenta.self) private var cuenta
    var alTerminar: () -> Void
    @State private var nombre = ""
    @State private var tuNombre = ""
    @State private var error: String?
    @State private var creando = false

    private var pideTuNombre: Bool { cuenta.usuario?.nombre == nil }

    private var listo: Bool {
        !Nombres.limpiar(nombre).isEmpty && (!pideTuNombre || !Nombres.limpiar(tuNombre).isEmpty)
    }

    var body: some View {
        Form {
            Section {
                TextField(Textos.Hogar.campoNombreHogar, text: $nombre)
                if pideTuNombre {
                    CampoTuNombre(nombre: $tuNombre)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let pasa = Textos.Hogar.pasaAlHogar(
                        categorias: cuenta.inventario.categorias.count,
                        productos: cuenta.inventario.cuantosProductos
                    ) {
                        Text(pasa)
                    }
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(Textos.Hogar.tituloNuevo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Textos.Hogar.botonCrear, action: crear)
                    .disabled(!listo || creando)
            }
        }
        .disabled(creando)
    }

    private func crear() {
        creando = true
        error = nil
        Task {
            let fallo = await cuenta.crearHogar(nombre: Nombres.limpiar(nombre), tuNombre: pideTuNombre ? tuNombre : nil)
            creando = false
            if let fallo {
                error = fallo
                anunciar(fallo)
            } else {
                alTerminar()
            }
        }
    }
}

struct FormularioUnirse: View {
    @Environment(Cuenta.self) private var cuenta
    var alTerminar: () -> Void
    @State private var codigo = ""
    @State private var tuNombre = ""
    @State private var error: String?
    @State private var uniendo = false
    @State private var preguntar: Hogar?

    private var pideTuNombre: Bool { cuenta.usuario?.nombre == nil }

    private var listo: Bool {
        !codigo.trimmingCharacters(in: .whitespaces).isEmpty
            && (!pideTuNombre || !Nombres.limpiar(tuNombre).isEmpty)
    }

    var body: some View {
        Form {
            Section {
                TextField(Textos.Hogar.campoCodigo, text: $codigo)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if pideTuNombre {
                    CampoTuNombre(nombre: $tuNombre)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Textos.Hogar.explicacionCodigo)
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(Textos.Hogar.tituloUnirme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Textos.Hogar.botonUnirme, action: unirse)
                    .disabled(!listo || uniendo)
            }
        }
        .disabled(uniendo)
        .alertaInventarioDelIphone(hogar: $preguntar) { hogar, conservando in
            Task {
                await cuenta.resolverInventario(hogar, conservando: conservando)
                alTerminar()
            }
        }
    }

    private func unirse() {
        uniendo = true
        error = nil
        Task {
            let resultado = await cuenta.unirse(codigo: codigo, tuNombre: pideTuNombre ? tuNombre : nil)
            uniendo = false
            switch resultado {
            case .hecho:
                alTerminar()
            case .preguntar(let hogar):
                preguntar = hogar
            case .error(let fallo):
                error = fallo
                anunciar(fallo)
            }
        }
    }
}

struct FormularioTuNombre: View {
    @Environment(Cuenta.self) private var cuenta
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var error: String?
    @State private var guardando = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CampoTuNombre(nombre: $nombre)
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Textos.Hogar.cambiarTuNombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.Botones.cancelar) { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.Botones.guardar, action: guardar)
                        .disabled(Nombres.limpiar(nombre).isEmpty || guardando)
                }
            }
        }
        .onAppear { nombre = cuenta.usuario?.nombre ?? "" }
    }

    private func guardar() {
        guardando = true
        Task {
            let fallo = await cuenta.cambiarNombre(nombre)
            guardando = false
            if let fallo {
                error = fallo
                anunciar(fallo)
            } else {
                cerrar()
            }
        }
    }
}

extension View {
    /// «Inventario de este iPhone» al unirse a un hogar con cosas guardadas.
    /// Sin Cancelar: ya se ha entrado en el hogar y las dos respuestas son definitivas.
    func alertaInventarioDelIphone(
        hogar: Binding<Hogar?>,
        responder: @escaping (Hogar, Bool) -> Void
    ) -> some View {
        modifier(AlertaInventarioDelIphone(hogar: hogar, responder: responder))
    }
}

private struct AlertaInventarioDelIphone: ViewModifier {
    @Environment(Cuenta.self) private var cuenta
    @Binding var hogar: Hogar?
    let responder: (Hogar, Bool) -> Void

    func body(content: Content) -> some View {
        let categorias = cuenta.inventario.categorias.count
        let productos = cuenta.inventario.cuantosProductos
        let soloCategorias = productos == 0
        content.alert(
            Textos.InventarioEnElIphone.titulo,
            isPresented: Binding(get: { hogar != nil }, set: { if !$0 { hogar = nil } }),
            presenting: hogar
        ) { elegido in
            Button(Textos.InventarioEnElIphone.anadir(soloCategorias: soloCategorias)) {
                responder(elegido, true)
            }
            Button(Textos.InventarioEnElIphone.eliminar(soloCategorias: soloCategorias), role: .destructive) {
                responder(elegido, false)
            }
        } message: { elegido in
            Text(Textos.InventarioEnElIphone.pregunta(categorias: categorias, productos: productos, hogar: elegido.nombre))
        }
    }
}
