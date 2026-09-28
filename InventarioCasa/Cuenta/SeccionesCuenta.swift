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
        case cerrarSesion, eliminarCuenta
        var id: Self { self }
    }

    var hoja: Hoja?
    var confirmar: Confirmacion?
    var error: String?
    var ocupado = false
    /// Los cambios que no se pudieron enviar antes de cerrar sesión, de todos los hogares.
    var pendientesAlCerrar = 0

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

/// Hogares y cuenta, al principio de Ajustes.
struct SeccionesCuenta: View {
    @Environment(Cuenta.self) private var cuenta
    let estado: EstadoAjustesCuenta

    var body: some View {
        if let usuario = cuenta.usuario {
            seccionHogares
            Section(Textos.Sesion.encabezado) {
                Text(Textos.Sesion.iniciadaComo(usuario.email))
                if cuenta.inventario.conHogar {
                    Text(Textos.estadoSincronizacion(pendientes: cuenta.pendientes, sinConexion: cuenta.sinConexion))
                }
                // El nombre es de la cuenta, no de un hogar.
                Button(Textos.Hogar.cambiarTuNombre) { estado.hoja = .tuNombre }
                Button(Textos.Sesion.cerrarSesion, action: cerrarSesion)
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
    private var seccionHogares: some View {
        if cuenta.hogares.isEmpty {
            Section(Textos.Hogar.encabezado) {
                Text(Textos.Hogar.sinHogar)
                Button(Textos.Hogar.crear) { estado.hoja = .crear }
                Button(Textos.Hogar.unirmeConCodigo) { estado.hoja = .unirse }
            }
        } else {
            Section(Textos.Hogares.encabezado) {
                ForEach(cuenta.hogares, id: \.id) { hogar in
                    fila(hogar)
                }
                Button(Textos.Hogar.crear) { estado.hoja = .crear }
                Button(Textos.Hogar.unirmeConCodigo) { estado.hoja = .unirse }
            }
        }
    }

    /// Pulsar abre su pantalla; «Abrir», en el rotor, cambia a él sin entrar.
    private func fila(_ hogar: Hogar) -> some View {
        let actual = hogar.id == cuenta.hogar?.id
        return NavigationLink {
            PantallaHogar(hogarId: hogar.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(hogar.nombre)
                if actual {
                    Text(Textos.Hogares.actual)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(actual ? Textos.Hogares.filaActual(hogar.nombre) : hogar.nombre)
        }
        .accessibilityActions {
            if !actual {
                Button(Textos.Hogares.abrir) {
                    estado.ejecutar { await cuenta.cambiar(a: hogar) }
                }
            }
        }
    }

    /// Antes de cerrar se envía lo de todos los hogares: al cerrar se quitan
    /// del iPhone los que no son el actual. Si algo no se pudo enviar, se pregunta.
    private func cerrarSesion() {
        estado.ocupado = true
        Task {
            let quedan = await cuenta.enviarTodo()
            estado.ocupado = false
            if quedan > 0 {
                estado.pendientesAlCerrar = quedan
                estado.confirmar = .cerrarSesion
            } else {
                await cuenta.cerrarSesion()
            }
        }
    }
}

/// Qué notificaciones recibir. Cada interruptor se guarda en el servidor al
/// tocarlo: es él quien decide a quién avisar.
struct SeccionNotificaciones: View {
    @Environment(Cuenta.self) private var cuenta
    @Environment(\.openURL) private var abrir
    let hogarId: String

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
        .task { await cuenta.cargarAvisos(de: hogarId) }
    }

    private func interruptor(_ texto: String, _ cual: WritableKeyPath<Avisos, Bool>) -> some View {
        Toggle(texto, isOn: Binding(
            get: { cuenta.avisosPorHogar[hogarId]?[keyPath: cual] ?? false },
            set: { valor in Task { await cuenta.cambiarAviso(cual, a: valor, en: hogarId) } }
        ))
        // Hasta saber qué hay en el servidor, no se puede cambiar.
        .disabled(cuenta.avisosPorHogar[hogarId] == nil)
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
    }

    private var botonCancelar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(Textos.Botones.cancelar) { estado.hoja = nil }
        }
    }

    private func titulo(_ cual: EstadoAjustesCuenta.Confirmacion?) -> String {
        switch cual {
        case .cerrarSesion: Textos.ConfirmacionCuenta.cerrarSesionTitulo
        case .eliminarCuenta: Textos.ConfirmacionCuenta.eliminarCuentaTitulo
        case nil: ""
        }
    }

    private func mensaje(_ cual: EstadoAjustesCuenta.Confirmacion) -> String {
        switch cual {
        case .cerrarSesion:
            Textos.ConfirmacionCuenta.cerrarSesionMensaje(pendientes: estado.pendientesAlCerrar)
        case .eliminarCuenta:
            Textos.ConfirmacionCuenta.eliminarCuentaMensaje(
                soloTuyos: cuenta.hogares.filter { $0.miembros.count <= 1 }.map(\.nombre),
                compartidos: cuenta.hogares.filter { $0.miembros.count > 1 }.map(\.nombre),
                conApple: cuenta.usuario?.esDeApple == true
            )
        }
    }

    private func boton(_ cual: EstadoAjustesCuenta.Confirmacion) -> String {
        switch cual {
        case .cerrarSesion: Textos.Sesion.cerrarSesion
        case .eliminarCuenta: Textos.Sesion.eliminarCuenta
        }
    }

    private func ejecutar(_ cual: EstadoAjustesCuenta.Confirmacion) {
        let cuenta = self.cuenta
        switch cual {
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
