import InventarioNucleo
import SwiftUI

/// La primera vez que se abre la app: iniciar sesión o usarla sin cuenta.
/// Si se inicia sesión y no hay hogar, «Tu hogar» sigue dentro de esta misma
/// pantalla: una hoja encima de otra que se está cerrando no llega a salir.
struct Bienvenida: View {
    @Environment(Cuenta.self) private var cuenta
    var alTerminar: () -> Void
    @State private var tuHogar = false
    @State private var unirse = false

    var body: some View {
        NavigationStack {
            Form {
                // Cada párrafo en su fila: en una sola, el sistema los junta
                // en un elemento y VoiceOver los lee de un tirón.
                Section {
                    Text(Textos.Bienvenida.queEs)
                    Text(Textos.Bienvenida.cuenta)
                }
                Section {
                    BotonesInicioSesion {
                        if cuenta.invitacion != nil, cuenta.hogar == nil {
                            unirse = true
                        } else if cuenta.pedirHogar {
                            tuHogar = true
                        } else if cuenta.decidirInventario == nil {
                            alTerminar()
                        }
                        // Con decidirInventario, se cierra al responder la alerta.
                    }
                    Button(Textos.Bienvenida.usarSinCuenta, action: alTerminar)
                } footer: {
                    Text(Textos.Bienvenida.masTarde)
                }
            }
            .navigationTitle(Textos.Bienvenida.titulo)
            .navigationDestination(isPresented: $unirse) {
                FormularioUnirse(codigoInicial: cuenta.invitacion, alTerminar: alTerminar)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(Textos.Botones.cancelar) {
                                cuenta.invitacion = nil
                                alTerminar()
                            }
                        }
                    }
            }
            .navigationDestination(isPresented: $tuHogar) {
                VistaTuHogar(alTerminar: alTerminar)
                    .navigationBarBackButtonHidden()
            }
        }
        .alertaInventarioDelIphone(
            hogar: Binding(get: { cuenta.decidirInventario }, set: { cuenta.decidirInventario = $0 })
        ) { hogar, conservando in
            Task {
                await cuenta.resolverInventario(hogar, conservando: conservando)
                alTerminar()
            }
        }
    }
}
