import SwiftUI
import InventarioNucleo
import InventarioAlmacen
import InventarioConexion

/// Abre el almacén (en `Arranque`) y, si no se puede leer, lo dice y deja
/// reintentar. Con el inventario abierto, decide si sale la bienvenida.
struct VistaRaiz: View {
    private var arranque: Arranque { .compartido }
    @State private var preparada = false
    @State private var bienvenida = false
    @State private var debeVerBienvenida = false
    @Environment(\.scenePhase) private var fase

    private static let claveBienvenida = "bienvenidaVista"

    var body: some View {
        Group {
            if preparada, let cuenta = arranque.cuenta {
                // El del hogar abierto: al cambiar de hogar, cambia y las pantallas con él.
                let inventario = cuenta.inventario
                VistaPrincipal()
                    .environment(inventario)
                    .fullScreenCover(isPresented: $bienvenida) {
                        Bienvenida { cerrarBienvenida() }
                            .environment(inventario)
                            .environment(cuenta)
                    }
                    .alertaInventarioDelIphone(
                        hogar: Binding(
                            get: { bienvenida ? nil : cuenta.decidirInventario },
                            set: { cuenta.decidirInventario = $0 }
                        )
                    ) { hogar, conservando in
                        Task { await cuenta.resolverInventario(hogar, conservando: conservando) }
                    }
                    // El enlace de invitación. Con la bienvenida delante, espera:
                    // la bienvenida lo recoge al iniciar sesión.
                    .sheet(isPresented: Binding(
                        get: { !bienvenida && cuenta.invitacion != nil && !cuenta.invitacionConHogar },
                        set: { if !$0 { cuenta.invitacion = nil } }
                    )) {
                        if let codigo = cuenta.invitacion {
                            HojaInvitacion(codigo: codigo)
                                .environment(inventario)
                                .environment(cuenta)
                        }
                    }
                    .alertaYaEnHogar(dentroDeLaHoja: false)
                    .onOpenURL { cuenta.abrirEnlace($0) }
                    .environment(cuenta)
                    .task {
                        // Aquí y no al crear la vista: presentar antes de que
                        // esté en la ventana a veces no llega a mostrar nada.
                        bienvenida = debeVerBienvenida
                        await arranque.arrancar()
                        // Al abrir, `fase` ya es .active y onChange no salta.
                        if fase == .active { cuenta.empezarASondear() }
                        #if DEBUG
                        // El simulador no verifica enlaces universales: las
                        // pruebas abren la invitación así.
                        let argumentos = ProcessInfo.processInfo.arguments
                        if let posicion = argumentos.firstIndex(of: "-abrirEnlace"),
                           argumentos.indices.contains(posicion + 1),
                           let url = URL(string: argumentos[posicion + 1]) {
                            cuenta.abrirEnlace(url)
                        }
                        #endif
                    }
                    .onChange(of: fase) { _, nueva in
                        if nueva == .active {
                            cuenta.empezarASondear()
                            Task { await cuenta.alVolver() }
                        } else {
                            cuenta.dejarDeSondear()
                            // Los productos que Siri reconoce en las frases.
                            Atajos.updateAppShortcutParameters()
                        }
                    }
                    // Solo cuando la cola crece: al confirmarse un envío se
                    // vacía, y eso no tiene que lanzar otro.
                    .onChange(of: inventario.pendientes.cuantos) { antes, ahora in
                        if ahora > antes { cuenta.programarSincronizacion() }
                    }
            } else if arranque.falloAlAbrir {
                ContentUnavailableView {
                    Label(Textos.Errores.noLeido, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(Textos.Botones.reintentar, action: abrir)
                }
            }
        }
        .onAppear(perform: abrir)
    }

    /// La bienvenida se decide una vez, aunque la cuenta ya existiera: Siri
    /// puede haber arrancado la app en segundo plano antes de abrirla.
    private func abrir() {
        guard !preparada, let cuenta = arranque.abrir() else { return }
        var yaVista = UserDefaults.standard.bool(forKey: Self.claveBienvenida)
        #if DEBUG
        let argumentos = ProcessInfo.processInfo.arguments
        // Las pruebas de interfaz arrancan vacías cada vez: sin esto, todas
        // empezarían en la bienvenida. La suya la pide con -conBienvenida.
        if (arranque.enMemoria || arranque.deEjemplo) && !argumentos.contains("-conBienvenida") { yaVista = true }
        // Y la que la pide la ve siempre: lo guardado en las preferencias
        // sobrevive entre arranques del simulador, y otra prueba ya la cerró.
        if argumentos.contains("-conBienvenida") { yaVista = false }
        #endif
        debeVerBienvenida = !yaVista
        cuenta.enBienvenida = debeVerBienvenida
        preparada = true
    }

    private func cerrarBienvenida() {
        UserDefaults.standard.set(true, forKey: Self.claveBienvenida)
        bienvenida = false
        arranque.cuenta?.enBienvenida = false
    }
}
