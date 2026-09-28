import SwiftUI
import InventarioNucleo
import InventarioAlmacen
import InventarioConexion

/// Abre el almacén y, si no se puede leer, lo dice y deja reintentar. Con el
/// inventario abierto, monta la cuenta y decide si sale la bienvenida.
struct VistaRaiz: View {
    @State private var cuenta: Cuenta?
    @State private var falloAlAbrir = false
    @State private var bienvenida = false
    @State private var debeVerBienvenida = false
    @Environment(\.scenePhase) private var fase

    private static let claveBienvenida = "bienvenidaVista"

    var body: some View {
        Group {
            if let cuenta {
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
                        await cuenta.arrancar()
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
                        }
                    }
                    // Solo cuando la cola crece: al confirmarse un envío se
                    // vacía, y eso no tiene que lanzar otro.
                    .onChange(of: inventario.pendientes.cuantos) { antes, ahora in
                        if ahora > antes { cuenta.programarSincronizacion() }
                    }
            } else if falloAlAbrir {
                ContentUnavailableView {
                    Label(Textos.Errores.noLeido, systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(Textos.Botones.reintentar, action: abrir)
                }
            }
        }
        .onAppear(perform: abrir)
    }

    private func abrir() {
        guard cuenta == nil else { return }
        let argumentos = ProcessInfo.processInfo.arguments
        #if DEBUG
        // Para capturas y pruebas a mano: datos de ejemplo en memoria, sin tocar los guardados.
        let deEjemplo = argumentos.contains("-datosDeEjemplo")
        // Para las pruebas de interfaz: SwiftData de verdad, pero vacío en cada arranque.
        let enMemoria = argumentos.contains("-almacenEnMemoria")
        #else
        let deEjemplo = false
        let enMemoria = false
        #endif
        do {
            let almacenamiento: Inventarios.Almacenamiento =
                deEjemplo ? .enMemoria(original: VistaPrevia.inventario())
                : enMemoria ? .enMemoria()
                : .enDisco
            let nueva = crearCuenta(try Inventarios(almacenamiento: almacenamiento), argumentos: argumentos)
            DelegadoApp.actual?.conectar(nueva)
            cuenta = nueva
            falloAlAbrir = false
        } catch {
            falloAlAbrir = true
        }

        var yaVista = UserDefaults.standard.bool(forKey: Self.claveBienvenida)
        #if DEBUG
        // Las pruebas de interfaz arrancan vacías cada vez: sin esto, todas
        // empezarían en la bienvenida. La suya la pide con -conBienvenida.
        if (enMemoria || deEjemplo) && !argumentos.contains("-conBienvenida") { yaVista = true }
        // Y la que la pide la ve siempre: lo guardado en las preferencias
        // sobrevive entre arranques del simulador, y otra prueba ya la cerró.
        if argumentos.contains("-conBienvenida") { yaVista = false }
        #endif
        debeVerBienvenida = !yaVista
        cuenta?.enBienvenida = debeVerBienvenida
    }

    private func cerrarBienvenida() {
        UserDefaults.standard.set(true, forKey: Self.claveBienvenida)
        bienvenida = false
        cuenta?.enBienvenida = false
    }

    #if DEBUG
    /// Sin la alerta del sistema, que las pruebas no controlan. Concedido,
    /// o denegado con -sinPermisoNotificaciones. El token es inventado.
    private static func permisoFalso(denegado: Bool) -> PermisoNotificaciones {
        PermisoNotificaciones(
            estado: { denegado ? .denegado : .concedido },
            pedir: { !denegado },
            registrar: {
                if let delegado = DelegadoApp.actual {
                    delegado.application(UIApplication.shared, didRegisterForRemoteNotificationsWithDeviceToken: Data(repeating: 0xab, count: 32))
                }
            }
        )
    }
    #endif

    private func crearCuenta(_ inventarios: Inventarios, argumentos: [String]) -> Cuenta {
        #if DEBUG
        // Para las pruebas de interfaz: un servidor en memoria, con el hogar
        // de Luis para probar a unirse (código LUISCASA). Google entra como
        // Ana y Apple como alguien sin nombre, igual que la Apple de verdad.
        if argumentos.contains("-servidorFalso") {
            let servidor = ServidorEnMemoria()
            servidor.sembrarHogar(nombre: "Casa de Luis", de: "Luis", codigo: "LUISCASA", categoria: "Nevera", producto: "Leche")
            // Luis añade algo con la app ya abierta: tiene que llegar sin cerrarla.
            if argumentos.contains("-cambioAjeno") {
                Task {
                    try? await Task.sleep(for: .seconds(20))
                    servidor.anadirProducto(de: "Luis", en: "Nevera", nombre: "Yogures")
                }
            }
            return Cuenta(
                inventarios: inventarios,
                conexion: ConexionEnMemoria(servidor: servidor),
                pedirCodigoGoogle: { _ in .exito(codigoDeCanje: "ana@ejemplo.com") },
                pedirIdentidadApple: { _ in .exito(identityToken: "x7k2mq@privaterelay.appleid.com", codigo: "codigo") },
                usaBotonAppleDelSistema: false,
                permiso: Self.permisoFalso(denegado: argumentos.contains("-sinPermisoNotificaciones"))
            )
        }
        #endif
        let google = IniciadorGoogle()
        let apple = IniciadorApple()
        return Cuenta(
            inventarios: inventarios,
            conexion: ConexionServidor(),
            pedirCodigoGoogle: { await google.pedirCodigo($0) },
            pedirIdentidadApple: { await apple.pedirIdentidad(resumenDelNonce: $0) }
        )
    }
}
