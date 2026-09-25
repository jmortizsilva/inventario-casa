import SwiftUI
import InventarioNucleo

struct VistaAjustes: View {
    @State private var mostrarManual = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
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
}
