import InventarioNucleo
import SwiftUI

/// Lo que abre un enlace de invitación: sin sesión, iniciarla; con sesión,
/// «Unirme a un hogar» con el código escrito.
struct HojaInvitacion: View {
    @Environment(Cuenta.self) private var cuenta
    let codigo: String

    var body: some View {
        NavigationStack {
            Group {
                if cuenta.conSesion {
                    FormularioUnirse(codigoInicial: codigo) { cuenta.invitacion = nil }
                } else {
                    Form {
                        Section {
                            Text(Textos.Invitacion.iniciaParaUnirte)
                        }
                        Section {
                            BotonesInicioSesion()
                        }
                    }
                    .navigationTitle(Textos.Hogar.tituloUnirme)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Textos.Botones.cancelar) { cuenta.invitacion = nil }
                }
            }
        }
        // Al iniciar sesión puede resultar que la cuenta ya tenga hogar.
        .alertaYaEnHogar(dentroDeLaHoja: true)
    }
}

extension View {
    /// «Ya estás en {hogar}», al abrir una invitación estando en un hogar.
    func alertaYaEnHogar(dentroDeLaHoja: Bool) -> some View {
        modifier(AlertaYaEnHogar(dentroDeLaHoja: dentroDeLaHoja))
    }
}

private struct AlertaYaEnHogar: ViewModifier {
    @Environment(Cuenta.self) private var cuenta
    let dentroDeLaHoja: Bool

    private var toca: Bool {
        guard cuenta.invitacion != nil else { return false }
        return dentroDeLaHoja ? cuenta.hogar != nil && !cuenta.invitacionConHogar : cuenta.invitacionConHogar
    }

    func body(content: Content) -> some View {
        content.alert(
            Textos.Invitacion.yaEnHogarTitulo(cuenta.hogar?.nombre ?? ""),
            isPresented: Binding(
                get: { toca },
                set: { if !$0 { cuenta.invitacion = nil } }
            )
        ) {
            Button(Textos.Botones.aceptar, role: .cancel) { cuenta.invitacion = nil }
        } message: {
            Text(Textos.Invitacion.yaEnHogarMensaje)
        }
    }
}
