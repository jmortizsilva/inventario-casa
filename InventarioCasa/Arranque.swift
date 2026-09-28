import Foundation
import InventarioAlmacen
import InventarioConexion
import InventarioNucleo
import Observation
import UIKit

/// La cuenta y el inventario, creados una sola vez por proceso. Los usan las
/// pantallas y las acciones de Siri: iOS puede arrancar la app en segundo
/// plano solo para una acción, sin crear ninguna vista, y el cambio tiene
/// que ir a la misma cola que los hechos a mano.
@MainActor
@Observable
final class Arranque {
    static let compartido = Arranque()

    private(set) var cuenta: Cuenta?
    private(set) var falloAlAbrir = false
    @ObservationIgnored private var sesion: Task<Void, Never>?

    /// Con datos de ejemplo o vacíos en memoria: las pruebas y las capturas.
    let deEjemplo: Bool
    let enMemoria: Bool

    private init() {
        #if DEBUG
        let argumentos = ProcessInfo.processInfo.arguments
        // Para capturas y pruebas a mano: datos de ejemplo en memoria, sin tocar los guardados.
        deEjemplo = argumentos.contains("-datosDeEjemplo")
        // Para las pruebas de interfaz: SwiftData de verdad, pero vacío en cada arranque.
        enMemoria = argumentos.contains("-almacenEnMemoria")
        #else
        deEjemplo = false
        enMemoria = false
        #endif
    }

    /// La cuenta, abriendo el almacén si hace falta. Nil si no se puede leer.
    @discardableResult
    func abrir() -> Cuenta? {
        if let cuenta { return cuenta }
        do {
            let almacenamiento: Inventarios.Almacenamiento =
                deEjemplo ? .enMemoria(original: VistaPrevia.inventario())
                : enMemoria ? .enMemoria()
                : .enDisco
            let nueva = crearCuenta(try Inventarios(almacenamiento: almacenamiento), argumentos: ProcessInfo.processInfo.arguments)
            DelegadoApp.actual?.conectar(nueva)
            cuenta = nueva
            falloAlAbrir = false
        } catch {
            falloAlAbrir = true
        }
        return cuenta
    }

    /// Tras un cambio desde Siri: Siri contesta sin esperar a la red, y el
    /// envío sigue con el tiempo extra que iOS da a una app que pasa a
    /// segundo plano. Sin conexión, el cambio espera en la cola.
    func enviarEnSegundoPlano() {
        guard let cuenta else { return }
        let app = UIApplication.shared
        if tareaDeFondo == .invalid {
            tareaDeFondo = app.beginBackgroundTask(withName: "Enviar cambios") { [weak self] in
                MainActor.assumeIsolated { self?.terminarTareaDeFondo() }
            }
        }
        Task {
            await arrancar()
            await cuenta.sincronizar()
            Atajos.updateAppShortcutParameters()
            terminarTareaDeFondo()
        }
    }

    @ObservationIgnored private var tareaDeFondo = UIBackgroundTaskIdentifier.invalid

    private func terminarTareaDeFondo() {
        guard tareaDeFondo != .invalid else { return }
        UIApplication.shared.endBackgroundTask(tareaDeFondo)
        tareaDeFondo = .invalid
    }

    /// Recupera la sesión y sincroniza, una sola vez. Si ya está en marcha, espera a que acabe.
    func arrancar() async {
        guard let cuenta = abrir() else { return }
        if sesion == nil { sesion = Task { await cuenta.arrancar() } }
        await sesion?.value
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
