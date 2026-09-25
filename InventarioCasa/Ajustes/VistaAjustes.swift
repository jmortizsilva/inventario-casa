import SwiftUI
import UniformTypeIdentifiers
import InventarioNucleo

struct VistaAjustes: View {
    @Environment(Inventario.self) private var inventario
    @State private var mostrarManual = false
    @State private var elegirArchivo = false
    @State private var aviso: Aviso?

    struct Aviso: Identifiable {
        let id = UUID()
        let titulo: String
        let mensaje: String?
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(Textos.Importacion.boton) { elegirArchivo = true }
                    Button(Textos.Botones.manual) { mostrarManual = true }
                }
                Section {
                    Text(Textos.version(version))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Textos.Titulos.ajustes)
        }
        .sheet(isPresented: $mostrarManual) {
            VistaManual()
        }
        .fileImporter(isPresented: $elegirArchivo, allowedContentTypes: [.json]) { resultado in
            if case .success(let url) = resultado {
                importar(url)
            }
        }
        .alert(
            aviso?.titulo ?? "",
            isPresented: Binding(get: { aviso != nil }, set: { if !$0 { aviso = nil } }),
            presenting: aviso
        ) { _ in
            Button(Textos.Botones.aceptar, role: .cancel) {}
        } message: { aviso in
            if let mensaje = aviso.mensaje {
                Text(mensaje)
            }
        }
    }

    /// El resultado va en una alerta y no en un anuncio: un anuncio se puede
    /// perder, y aquí importa saber qué no se importó.
    private func importar(_ url: URL) {
        // El archivo viene de Archivos, fuera de la app: hay que pedir acceso.
        let conAcceso = url.startAccessingSecurityScopedResource()
        defer {
            if conAcceso { url.stopAccessingSecurityScopedResource() }
        }
        let exportacion: Exportacion
        do {
            exportacion = try Exportacion.leer(Data(contentsOf: url))
        } catch {
            aviso = Aviso(titulo: Textos.Importacion.noImportadoTitulo, mensaje: Textos.Importacion.archivoNoValido)
            return
        }
        do {
            let resultado = try inventario.importar(exportacion)
            aviso = Aviso(titulo: Textos.Importacion.titulo(resultado), mensaje: Textos.Importacion.mensaje(resultado))
        } catch {
            aviso = Aviso(titulo: Textos.Importacion.noImportadoTitulo, mensaje: Textos.Errores.noGuardadoMensaje)
        }
    }
}

struct VistaManual: View {
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Textos.manual, id: \.titulo) { apartado in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(apartado.titulo)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(apartado.texto)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(Textos.Titulos.manual)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Textos.Botones.cerrar) { cerrar() }
                }
            }
        }
    }
}

#Preview {
    VistaAjustes()
        .environment(VistaPrevia.inventario())
}
