import AppIntents
import Intents
import IntentsUI
import InventarioNucleo
import SwiftUI

/// Ajustes > Siri: una fila por acción. Al pulsarla se abre la hoja de Apple
/// para añadir la frase o, si ya tiene, para cambiarla o eliminarla. Lo que
/// se guarda aquí va a la app Atajos, igual que en Seeing AI.
struct PantallaSiri: View {
    @State private var frases: [AccionVoz: INVoiceShortcut] = [:]
    @State private var hoja: HojaSiri.Contenido?

    var body: some View {
        List {
            Section {
                ForEach(AccionVoz.allCases, id: \.self) { accion in
                    Button {
                        hoja = frases[accion].map { .editar($0) } ?? .anadir(accion)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Textos.Siri.titulo(accion))
                                .foregroundStyle(.primary)
                            Text(frases[accion].map { Textos.Siri.frase($0.invocationPhrase) } ?? Textos.Siri.sinFrase)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
            } footer: {
                Text(Textos.Siri.pie)
            }
            Section {
                ShortcutsLink()
            }
        }
        .navigationTitle(Textos.Siri.titulo)
        .task { frases = await HojaSiri.frasesGuardadas() }
        .sheet(item: $hoja) { contenido in
            HojaSiri(contenido: contenido) {
                hoja = nil
                Task { frases = await HojaSiri.frasesGuardadas() }
            }
            .ignoresSafeArea()
        }
    }
}

/// Las hojas de «Añadir a Siri» y de editar una frase, que son de UIKit.
struct HojaSiri: UIViewControllerRepresentable {
    enum Contenido: Identifiable {
        case anadir(AccionVoz)
        case editar(INVoiceShortcut)

        var id: String {
            switch self {
            case .anadir(let accion): "anadir-\(accion)"
            case .editar(let guardada): guardada.identifier.uuidString
            }
        }
    }

    let contenido: Contenido
    let alTerminar: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        switch contenido {
        case .anadir(let accion):
            let hoja = INUIAddVoiceShortcutViewController(shortcut: Self.atajo(accion))
            hoja.delegate = context.coordinator
            return hoja
        case .editar(let guardada):
            let hoja = INUIEditVoiceShortcutViewController(voiceShortcut: guardada)
            hoja.delegate = context.coordinator
            return hoja
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    final class Coordinador: NSObject, INUIAddVoiceShortcutViewControllerDelegate, INUIEditVoiceShortcutViewControllerDelegate {
        let alTerminar: () -> Void

        init(alTerminar: @escaping () -> Void) { self.alTerminar = alTerminar }

        func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: (any Error)?) {
            alTerminar()
        }

        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
            alTerminar()
        }

        func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didUpdate voiceShortcut: INVoiceShortcut?, error: (any Error)?) {
            alTerminar()
        }

        func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
            alTerminar()
        }

        func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
            alTerminar()
        }
    }

    /// La acción sin datos: Siri pregunta el producto y las unidades al usarla.
    static func atajo(_ accion: AccionVoz) -> INShortcut {
        let intent: INIntent = switch accion {
        case .crearProducto: CrearProductoVozIntent()
        case .anadirUnidades: AnadirUnidadesVozIntent()
        case .quitarUnidades: QuitarUnidadesVozIntent()
        case .cambiarCantidad: CambiarCantidadVozIntent()
        case .consultarProducto: ConsultarProductoVozIntent()
        case .eliminarProducto: EliminarProductoVozIntent()
        }
        intent.suggestedInvocationPhrase = Textos.Siri.fraseSugerida(accion)
        // Las acciones están en Voz.intentdefinition: si no se pudiera crear,
        // sería un error de compilación del proyecto, no algo del usuario.
        return INShortcut(intent: intent)!
    }

    /// Qué acciones tienen ya frase, según Atajos.
    @MainActor
    static func frasesGuardadas() async -> [AccionVoz: INVoiceShortcut] {
        let guardadas = (try? await INVoiceShortcutCenter.shared.allVoiceShortcuts()) ?? []
        var frases: [AccionVoz: INVoiceShortcut] = [:]
        for guardada in guardadas {
            if let accion = accion(de: guardada.shortcut.intent) { frases[accion] = guardada }
        }
        return frases
    }

    private static func accion(de intent: INIntent?) -> AccionVoz? {
        switch intent {
        case is CrearProductoVozIntent: .crearProducto
        case is AnadirUnidadesVozIntent: .anadirUnidades
        case is QuitarUnidadesVozIntent: .quitarUnidades
        case is CambiarCantidadVozIntent: .cambiarCantidad
        case is ConsultarProductoVozIntent: .consultarProducto
        case is EliminarProductoVozIntent: .eliminarProducto
        default: nil
        }
    }
}
