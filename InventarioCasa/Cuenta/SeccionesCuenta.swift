import InventarioConexion
import InventarioNucleo
import SwiftUI
import UIKit

/// Lo que abren las secciones de cuenta: hojas, confirmaciones y el error.
/// Vive fuera de la lista porque las presentaciones no pueden colgar de sus
/// filas: un modificador puesto a varias filas se copia en cada una, y ninguna
/// copia llega a presentar nada.
@MainActor
@Observable
final class EstadoAjustesCuenta {
    enum Hoja: String, Identifiable {
        case crear, unirse, tuNombre
        var id: String { rawValue }
    }

    enum Confirmacion: Identifiable {
        case salir, cerrarSesion, eliminarCuenta
        var id: Self { self }
    }

    struct TextoParaCompartir: Identifiable {
        let id = UUID()
        let texto: String
    }

    var hoja: Hoja?
    var confirmar: Confirmacion?
    var invitacion: Invitacion?
    var compartir: TextoParaCompartir?
    var error: String?
    var ocupado = false

    func ejecutar(_ accion: @escaping () async -> String?) {
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

/// Hogar y cuenta, al principio de Ajustes.
struct SeccionesCuenta: View {
    @Environment(Cuenta.self) private var cuenta
    let estado: EstadoAjustesCuenta

    var body: some View {
        if let usuario = cuenta.usuario {
            seccionHogar
            if cuenta.hogar != nil {
                SeccionNotificaciones()
            }
            Section(Textos.Sesion.encabezado) {
                Text(Textos.Sesion.iniciadaComo(usuario.email))
                if cuenta.inventario.conHogar {
                    Text(Textos.estadoSincronizacion(pendientes: cuenta.pendientes, sinConexion: cuenta.sinConexion))
                }
                Button(Textos.Sesion.cerrarSesion) {
                    if cuenta.pendientes > 0 {
                        estado.confirmar = .cerrarSesion
                    } else {
                        Task { await cuenta.cerrarSesion() }
                    }
                }
                .disabled(estado.ocupado)
                Button(Textos.Sesion.eliminarCuenta, role: .destructive) { estado.confirmar = .eliminarCuenta }
                    .disabled(estado.ocupado)
                if let error = estado.error {
                    Text(error).foregroundStyle(.red)
                }
            }
        } else {
            Section(Textos.Sesion.encabezado) {
                if cuenta.sesionCaducada {
                    Text(Textos.Sesion.caducada)
                }
                Text(Textos.Sesion.sinCuenta)
                BotonesInicioSesion()
            }
        }
    }

    @ViewBuilder
    private var seccionHogar: some View {
        if let hogar = cuenta.hogar {
            Section(Textos.Hogar.encabezado) {
                Text(Textos.Hogar.personas(hogar.miembros.map { $0.nombre ?? $0.email }))
                Button(Textos.Hogar.invitar, action: invitar)
                    .disabled(estado.ocupado)
                Button(Textos.Hogar.cambiarTuNombre) { estado.hoja = .tuNombre }
                Button(Textos.Hogar.salir, role: .destructive) { estado.confirmar = .salir }
                    .disabled(estado.ocupado)
            }
        } else {
            Section(Textos.Hogar.encabezado) {
                Text(Textos.Hogar.sinHogar)
                Button(Textos.Hogar.crear) { estado.hoja = .crear }
                Button(Textos.Hogar.unirmeConCodigo) { estado.hoja = .unirse }
            }
        }
    }

    private func invitar() {
        estado.ocupado = true
        estado.error = nil
        Task {
            switch await cuenta.invitar() {
            case .success(let nueva): estado.invitacion = nueva
            case .failure(let fallo):
                estado.error = fallo.texto
                anunciar(fallo.texto)
            }
            estado.ocupado = false
        }
    }
}

/// Qué notificaciones recibir. Cada interruptor se guarda en el servidor al
/// tocarlo: es él quien decide a quién avisar.
private struct SeccionNotificaciones: View {
    @Environment(Cuenta.self) private var cuenta
    @Environment(\.openURL) private var abrir

    var body: some View {
        Section {
            interruptor(Textos.Notificaciones.productosNuevos, \.productosNuevos)
            interruptor(Textos.Notificaciones.categoriasNuevas, \.categoriasNuevas)
            interruptor(Textos.Notificaciones.entraEnLista, \.entraEnLista)
            interruptor(Textos.Notificaciones.saleDeLista, \.saleDeLista)
            interruptor(Textos.Notificaciones.personasNuevas, \.personasNuevas)
            if cuenta.permisoDenegado {
                Text(Textos.Notificaciones.desactivadas)
                Button(Textos.Notificaciones.abrirAjustes) {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { abrir(url) }
                }
            }
        } header: {
            Text(Textos.Notificaciones.encabezado)
        } footer: {
            Text(Textos.Notificaciones.pie)
        }
        .task { await cuenta.cargarAvisos() }
    }

    private func interruptor(_ texto: String, _ cual: WritableKeyPath<Avisos, Bool>) -> some View {
        Toggle(texto, isOn: Binding(
            get: { cuenta.avisos?[keyPath: cual] ?? false },
            set: { valor in Task { await cuenta.cambiarAviso(cual, a: valor) } }
        ))
        // Hasta saber qué hay en el servidor, no se puede cambiar.
        .disabled(cuenta.avisos == nil)
    }
}

/// Las hojas y alertas de las secciones de cuenta. Se ponen sobre la lista entera.
struct PresentacionesCuenta: ViewModifier {
    @Environment(Cuenta.self) private var cuenta
    @Bindable var estado: EstadoAjustesCuenta

    func body(content: Content) -> some View {
        content
            .sheet(item: $estado.hoja) { hoja in
                switch hoja {
                case .crear:
                    NavigationStack {
                        FormularioCrearHogar { estado.hoja = nil }
                            .toolbar { botonCancelar }
                    }
                case .unirse:
                    NavigationStack {
                        FormularioUnirse { estado.hoja = nil }
                            .toolbar { botonCancelar }
                    }
                case .tuNombre:
                    FormularioTuNombre()
                }
            }
            .sheet(isPresented: Binding(
                get: { cuenta.pedirHogar && !cuenta.enBienvenida && cuenta.invitacion == nil },
                set: { cuenta.pedirHogar = $0 }
            )) {
                NavigationStack {
                    VistaTuHogar { cuenta.pedirHogar = false }
                }
            }
            .alert(
                titulo(estado.confirmar),
                isPresented: Binding(get: { estado.confirmar != nil }, set: { if !$0 { estado.confirmar = nil } }),
                presenting: estado.confirmar
            ) { cual in
                Button(boton(cual), role: .destructive) { ejecutar(cual) }
                Button(Textos.Botones.cancelar, role: .cancel) {}
            } message: { cual in
                Text(mensaje(cual))
            }
            .alert(
                Textos.Invitacion.titulo,
                isPresented: Binding(get: { estado.invitacion != nil }, set: { if !$0 { estado.invitacion = nil } }),
                presenting: estado.invitacion
            ) { invitacion in
                Button(Textos.Invitacion.compartir) {
                    estado.compartir = .init(texto: Textos.Invitacion.textoCompartido(
                        codigo: invitacion.codigo, caduca: Date(milisegundos: invitacion.caducaEn)
                    ))
                }
                Button(Textos.Botones.aceptar, role: .cancel) {}
            } message: { invitacion in
                Text(Textos.Invitacion.mensaje(codigo: invitacion.codigo, caduca: Date(milisegundos: invitacion.caducaEn)))
            }
            .sheet(item: $estado.compartir) { texto in
                HojaCompartir(texto: texto.texto)
            }
    }

    private var botonCancelar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Textos.Botones.cancelar) { estado.hoja = nil }
        }
    }

    private var esLaUltima: Bool { (cuenta.hogar?.miembros.count ?? 0) <= 1 }

    private func titulo(_ cual: EstadoAjustesCuenta.Confirmacion?) -> String {
        switch cual {
        case .salir: Textos.ConfirmacionCuenta.salirTitulo(cuenta.hogar?.nombre ?? "")
        case .cerrarSesion: Textos.ConfirmacionCuenta.cerrarSesionTitulo
        case .eliminarCuenta: Textos.ConfirmacionCuenta.eliminarCuentaTitulo
        case nil: ""
        }
    }

    private func mensaje(_ cual: EstadoAjustesCuenta.Confirmacion) -> String {
        switch cual {
        case .salir:
            Textos.ConfirmacionCuenta.salirMensaje(ultimaPersona: esLaUltima)
        case .cerrarSesion:
            Textos.ConfirmacionCuenta.cerrarSesionMensaje(pendientes: cuenta.pendientes)
        case .eliminarCuenta:
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(
                hogar: cuenta.hogar?.nombre, ultimaPersona: esLaUltima, conApple: cuenta.usuario?.esDeApple == true
            )
        }
    }

    private func boton(_ cual: EstadoAjustesCuenta.Confirmacion) -> String {
        switch cual {
        case .salir: Textos.ConfirmacionCuenta.salirBoton
        case .cerrarSesion: Textos.Sesion.cerrarSesion
        case .eliminarCuenta: Textos.Sesion.eliminarCuenta
        }
    }

    private func ejecutar(_ cual: EstadoAjustesCuenta.Confirmacion) {
        let cuenta = self.cuenta
        switch cual {
        case .salir: estado.ejecutar { await cuenta.salir() }
        case .cerrarSesion: estado.ejecutar { await cuenta.cerrarSesion(); return nil }
        case .eliminarCuenta: estado.ejecutar { await cuenta.eliminarCuenta() }
        }
    }
}

/// La hoja de compartir del sistema, con el texto de la invitación.
struct HojaCompartir: UIViewControllerRepresentable {
    let texto: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [texto], applicationActivities: nil)
    }

    func updateUIViewController(_ controlador: UIActivityViewController, context: Context) {}
}
