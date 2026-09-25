import SwiftUI

/// Anuncio de VoiceOver. Con prioridad alta para que no lo corte el cambio de
/// foco al cerrar una hoja o una alerta, que es justo cuando más se anuncia.
@MainActor
func anunciar(_ texto: String) {
    var atribuido = AttributedString(texto)
    atribuido.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(atribuido).post()
}
