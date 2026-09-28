import InventarioConexion
import InventarioNucleo
import SwiftUI

/// Un hogar de la cuenta: abrirlo, quién está, invitar, qué notificaciones
/// recibir de él y salir. Se configura aunque no sea el actual.
struct PantallaHogar: View {
    @Environment(Cuenta.self) private var cuenta
    @Environment(\.dismiss) private var volver
    let hogarId: String

    @State private var invitacion: Invitacion?
    @State private var compartir: TextoParaCompartir?
    @State private var confirmarSalir = false
    @State private var error: String?
    @State private var ocupado = false

    struct TextoParaCompartir: Identifiable {
        let id = UUID()
        let texto: String
    }

    private var hogar: Hogar? { cuenta.hogares.first { $0.id == hogarId } }
    private var esElActual: Bool { cuenta.hogar?.id == hogarId }

    var body: some View {
        Form {
            if let hogar {
                if !esElActual {
                    Section {
                        Button(Textos.Hogares.abrirEste) { ejecutar { await cuenta.cambiar(a: hogar) } }
                    }
                }
                Section {
                    Text(Textos.Hogar.personas(hogar.miembros.map { $0.nombre ?? $0.email }))
                    Button(Textos.Hogar.invitar, action: invitar)
                }
                SeccionNotificaciones(hogarId: hogarId)
                Section {
                    Button(Textos.Hogar.salir, role: .destructive) { confirmarSalir = true }
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
        }
        .disabled(ocupado)
        .navigationTitle(hogar?.nombre ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Si deja de estar en él (salió, o lo sacaron desde otro sitio), no queda nada que ver.
        .onChange(of: hogar == nil) { _, sinHogar in if sinHogar { volver() } }
        .alert(
            Textos.ConfirmacionCuenta.salirTitulo(hogar?.nombre ?? ""),
            isPresented: $confirmarSalir
        ) {
            Button(Textos.ConfirmacionCuenta.salirBoton, role: .destructive, action: salir)
            Button(Textos.Botones.cancelar, role: .cancel) {}
        } message: {
            Text(Textos.ConfirmacionCuenta.salirMensaje(
                ultimaPersona: (hogar?.miembros.count ?? 0) <= 1,
                conOtros: cuenta.hogares.count > 1
            ))
        }
        .alert(
            Textos.Invitacion.titulo,
            isPresented: Binding(get: { invitacion != nil }, set: { if !$0 { invitacion = nil } }),
            presenting: invitacion
        ) { invitacion in
            Button(Textos.Invitacion.compartir) {
                compartir = .init(texto: Textos.Invitacion.textoCompartido(
                    codigo: invitacion.codigo, caduca: Date(milisegundos: invitacion.caducaEn)
                ))
            }
            Button(Textos.Botones.aceptar, role: .cancel) {}
        } message: { invitacion in
            Text(Textos.Invitacion.mensaje(codigo: invitacion.codigo, caduca: Date(milisegundos: invitacion.caducaEn)))
        }
        .sheet(item: $compartir) { texto in
            HojaCompartir(texto: texto.texto)
        }
    }

    private func invitar() {
        guard let hogar else { return }
        ocupado = true
        error = nil
        Task {
            switch await cuenta.invitar(a: hogar) {
            case .success(let nueva): invitacion = nueva
            case .failure(let fallo):
                error = fallo.texto
                anunciar(fallo.texto)
            }
            ocupado = false
        }
    }

    private func salir() {
        guard let hogar else { return }
        ejecutar { await cuenta.salir(de: hogar) }
    }

    private func ejecutar(_ accion: @escaping () async -> String?) {
        ocupado = true
        error = nil
        Task {
            let fallo = await accion()
            ocupado = false
            if let fallo {
                error = fallo
                anunciar(fallo)
            }
        }
    }
}
