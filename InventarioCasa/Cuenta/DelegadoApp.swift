import UIKit
import UserNotifications

/// Lo que iOS solo cuenta al delegado de la app: el token para las
/// notificaciones y las que llegan con la app abierta.
@MainActor
final class DelegadoApp: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// El que está en marcha. Lo conecta `Arranque` con la cuenta al crearla.
    static weak var actual: DelegadoApp?

    private weak var cuenta: Cuenta?
    /// Si iOS da el token antes de que exista la cuenta, espera aquí.
    private var tokenSinEntregar: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.actual = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func conectar(_ cuenta: Cuenta) {
        self.cuenta = cuenta
        if let token = tokenSinEntregar {
            tokenSinEntregar = nil
            Task { await cuenta.recibirToken(token) }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        if let cuenta {
            Task { await cuenta.recibirToken(token) }
        } else {
            tokenSinEntregar = token
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        // Sin token no hay notificaciones, pero la app funciona igual. Se reintenta al abrir.
    }

    /// Con la app abierta, la notificación se enseña igual, y además se
    /// sincroniza en el momento: si avisa de algo, ese algo ya ha cambiado.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            if let cuenta = self.cuenta { Task { await cuenta.sincronizar() } }
        }
        return [.banner, .list, .sound]
    }
}
