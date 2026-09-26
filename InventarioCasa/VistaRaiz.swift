import SwiftUI
import InventarioNucleo
import InventarioAlmacen
import InventarioConexion

/// Abre el almacén y, si no se puede leer, lo dice y deja reintentar. Con el
/// inventario abierto, monta la cuenta y decide si sale la bienvenida.
struct VistaRaiz: View {
    @State private var inventario: Inventario?
    @State private var cuenta: Cuenta?
    @State private var falloAlAbrir = false
    @State private var bienvenida = false
    @State private var debeVerBienvenida = false
    @Environment(\.scenePhase) private var fase

    private static let claveBienvenida = "bienvenidaVista"

    var body: some View {
        Group {
            if let inventario, let cuenta {
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
                    .environment(cuenta)
                    .task {
                        // Aquí y no al crear la vista: presentar antes de que
                        // esté en la ventana a veces no llega a mostrar nada.
                        bienvenida = debeVerBienvenida
                        await cuenta.arrancar()
                    }
                    .onChange(of: fase) { _, nueva in
                        if nueva == .active { Task { await cuenta.alVolver() } }
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
        guard inventario == nil else { return }
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
            let nuevo: Inventario
            if deEjemplo {
                nuevo = VistaPrevia.inventario()
            } else {
                let almacen = enMemoria ? try AlmacenSwiftData.enMemoria() : try AlmacenSwiftData.enDisco()
                nuevo = Inventario(almacen: almacen)
                try nuevo.cargar()
            }
            cuenta = crearCuenta(nuevo, argumentos: argumentos)
            inventario = nuevo
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

    private func crearCuenta(_ inventario: Inventario, argumentos: [String]) -> Cuenta {
        #if DEBUG
        // Para las pruebas de interfaz: un servidor en memoria, con el hogar
        // de Luis para probar a unirse (código LUISCASA). Google entra como
        // Ana y Apple como alguien sin nombre, igual que la Apple de verdad.
        if argumentos.contains("-servidorFalso") {
            let servidor = ServidorEnMemoria()
            servidor.sembrarHogar(nombre: "Casa de Luis", de: "Luis", codigo: "LUISCASA", categoria: "Nevera", producto: "Leche")
            return Cuenta(
                inventario: inventario,
                conexion: ConexionEnMemoria(servidor: servidor),
                pedirCodigoGoogle: { _ in .exito(codigoDeCanje: "ana@ejemplo.com") },
                pedirIdentidadApple: { _ in .exito(identityToken: "x7k2mq@privaterelay.appleid.com", codigo: "codigo") },
                usaBotonAppleDelSistema: false
            )
        }
        #endif
        let google = IniciadorGoogle()
        let apple = IniciadorApple()
        return Cuenta(
            inventario: inventario,
            conexion: ConexionServidor(),
            pedirCodigoGoogle: { await google.pedirCodigo($0) },
            pedirIdentidadApple: { await apple.pedirIdentidad(resumenDelNonce: $0) }
        )
    }
}
