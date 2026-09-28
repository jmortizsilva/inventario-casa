import InventarioNucleo
import SwiftUI

extension View {
    /// Deshacer lo último eliminado en esta pantalla: botón en la barra y
    /// agitar el iPhone. `aplica` dice qué eliminaciones son de esta pantalla.
    func deshacerEliminacion(cuando aplica: @escaping (Eliminacion) -> Bool) -> some View {
        modifier(DeshacerEliminacion(aplica: aplica))
    }
}

/// El botón sigue hasta otro cambio o hasta salir de la pantalla: con
/// VoiceOver, llegar a la barra lleva su tiempo, y uno que desaparece a los
/// diez segundos no se llega a usar.
private struct DeshacerEliminacion: ViewModifier {
    @Environment(Inventario.self) private var inventario
    let aplica: (Eliminacion) -> Bool
    /// Propio y no el del entorno: iOS busca qué deshacer en el primer
    /// respondedor, y en estas pantallas no hay ninguno. `ReceptorAgitar` lo es
    /// mientras haya algo que deshacer, y ofrece este.
    @State private var undoManager: UndoManager? = UndoManager()
    @State private var errorAlGuardar = false

    private var actual: Eliminacion? {
        inventario.ultimaEliminacion.flatMap { aplica($0) ? $0 : nil }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                if let eliminacion = actual {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Textos.Deshacer.boton, action: deshacer)
                            // «Deshacer» solo no dice qué se deshace.
                            .accessibilityLabel(Textos.Deshacer.etiqueta(eliminacion.nombre))
                    }
                }
            }
            .background(ReceptorAgitar(gestor: undoManager, activo: actual != nil))
            .onChange(of: inventario.ultimaEliminacion) { _, nueva in prepararAgitar(nueva) }
            .onDisappear { inventario.olvidarEliminacion() }
            .alertaNoGuardado(isPresented: $errorAlGuardar)
    }

    /// Al agitar, iOS pregunta «Deshacer {acción}» si su UndoManager tiene
    /// algo. Se deja solo lo último: lo anterior ya no se puede deshacer.
    private func prepararAgitar(_ eliminacion: Eliminacion?) {
        undoManager?.removeAllActions()
        guard let eliminacion, aplica(eliminacion) else { return }
        // Se captura el inventario, no la vista: iOS llama a esto fuera del
        // ciclo de SwiftUI, y ahí el entorno de una copia de la vista no vale.
        let gestor = undoManager
        undoManager?.registerUndo(withTarget: inventario) { inventario in
            Task { @MainActor in
                if !Self.deshacer(en: inventario, gestor: gestor) {
                    anunciar(Textos.Errores.noGuardadoMensaje)
                }
            }
        }
        undoManager?.setActionName(Textos.Deshacer.accion(eliminacion.nombre))
    }

    private func deshacer() {
        if !Self.deshacer(en: inventario, gestor: undoManager) { errorAlGuardar = true }
    }

    /// Devuelve false si no se pudo guardar.
    private static func deshacer(en inventario: Inventario, gestor: UndoManager?) -> Bool {
        do {
            guard let recuperada = try inventario.deshacerEliminacion() else { return true }
            gestor?.removeAllActions()
            switch recuperada {
            case .producto(let producto):
                anunciar(Textos.Deshacer.productoRecuperado(producto.nombre))
            case .categoria(let categoria, let productos):
                anunciar(Textos.Deshacer.categoriaRecuperada(categoria.nombre, productos: productos.count))
            }
            return true
        } catch {
            return false
        }
    }
}

/// Una vista invisible que se hace primer respondedor mientras hay algo que
/// deshacer: sin primer respondedor con un UndoManager que pueda deshacer,
/// agitar no hace nada (comprobado en el simulador con el UndoManager del
/// entorno de SwiftUI). No es elemento de accesibilidad ni mueve el foco de
/// VoiceOver, y no saca teclado.
private struct ReceptorAgitar: UIViewRepresentable {
    let gestor: UndoManager?
    let activo: Bool

    func makeUIView(context: Context) -> Receptor {
        let vista = Receptor()
        vista.isAccessibilityElement = false
        vista.isUserInteractionEnabled = false
        return vista
    }

    func updateUIView(_ vista: Receptor, context: Context) {
        vista.gestor = gestor
        if activo {
            // Tras presentarse la vista: antes de estar en la ventana no puede serlo.
            DispatchQueue.main.async { vista.becomeFirstResponder() }
        } else if vista.isFirstResponder {
            vista.resignFirstResponder()
        }
    }

    final class Receptor: UIView {
        var gestor: UndoManager?
        override var canBecomeFirstResponder: Bool { true }
        override var undoManager: UndoManager? { gestor }
    }
}
