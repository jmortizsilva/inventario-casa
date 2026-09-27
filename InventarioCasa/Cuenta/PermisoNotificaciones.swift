import UIKit
import UserNotifications

/// El permiso de iOS para las notificaciones, sustituible en las pruebas:
/// la alerta del sistema que lo pide no la controlan las pruebas de interfaz.
struct PermisoNotificaciones {
    enum Estado { case sinPreguntar, concedido, denegado }

    var estado: @MainActor () async -> Estado
    /// Pide permiso a iOS. Devuelve si se concedió.
    var pedir: @MainActor () async -> Bool
    /// Pide el token a iOS; llega al delegado de la app.
    var registrar: @MainActor () -> Void

    static let sistema = PermisoNotificaciones(
        estado: {
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .notDetermined: .sinPreguntar
            case .denied: .denegado
            default: .concedido
            }
        },
        pedir: {
            (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        },
        registrar: { UIApplication.shared.registerForRemoteNotifications() }
    )
}
