import SwiftUI
import InventarioNucleo

extension View {
    /// La misma alerta para cualquier fallo al guardar.
    func alertaNoGuardado(isPresented: Binding<Bool>) -> some View {
        alert(Textos.Errores.noGuardadoTitulo, isPresented: isPresented) {
            Button(Textos.Botones.aceptar, role: .cancel) {}
        } message: {
            Text(Textos.Errores.noGuardadoMensaje)
        }
    }
}
