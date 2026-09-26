import AuthenticationServices
import InventarioConexion
import InventarioNucleo
import UIKit

/// Las dos hojas del sistema para iniciar sesión, copiadas de Guardar Enlaces.
/// Viven en la app porque necesitan una ventana donde presentarse.

@MainActor
private func ventanaActiva() -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first { $0.isKeyWindow } ?? ASPresentationAnchor()
}

/// Google, por la hoja de Safari. La vuelta la captura la propia hoja, así que
/// no pasa por el manejador de enlaces de la app ni hace falta registrar el
/// esquema en el Info.plist.
///
/// Sin sesión efímera: comparte las cookies de Safari, y si ya hay sesión de
/// Google en el iPhone basta con confirmar la cuenta.
@MainActor
final class IniciadorGoogle: NSObject, ASWebAuthenticationPresentationContextProviding {
    func pedirCodigo(_ url: URL) async -> Login.Resultado {
        await withCheckedContinuation { continuacion in
            let hoja = ASWebAuthenticationSession(url: url, callbackURLScheme: Login.esquema) { vuelta, _ in
                // Sin vuelta es que cerró la hoja o no dio permiso: no es una avería.
                continuacion.resume(returning: vuelta.map(Login.leerCallback) ?? .cancelado)
            }
            hoja.presentationContextProvider = self
            if !hoja.start() {
                continuacion.resume(returning: .error(.servidorNoResponde))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { ventanaActiva() }
    }
}

enum ResultadoApple: Equatable {
    /// `codigo` es el authorizationCode: lo pide el servidor para revocar el
    /// acceso al eliminar la cuenta.
    case exito(identityToken: String, codigo: String)
    case cancelado
    case error
}

/// Apple, sin salir de la app. A Apple se le manda solo el resumen del nonce.
@MainActor
final class IniciadorApple: NSObject {
    private var continuacion: CheckedContinuation<ResultadoApple, Never>?
    private var controlador: ASAuthorizationController?

    func pedirIdentidad(resumenDelNonce: String) async -> ResultadoApple {
        await withCheckedContinuation { continuacion in
            self.continuacion = continuacion
            let solicitud = ASAuthorizationAppleIDProvider().createRequest()
            // Solo el correo: el nombre se pide en la app, al crear o unirse a un hogar.
            solicitud.requestedScopes = [.email]
            solicitud.nonce = resumenDelNonce
            let controlador = ASAuthorizationController(authorizationRequests: [solicitud])
            controlador.delegate = self
            controlador.presentationContextProvider = self
            self.controlador = controlador
            controlador.performRequests()
        }
    }

    private func responder(_ resultado: ResultadoApple) {
        continuacion?.resume(returning: resultado)
        continuacion = nil
        controlador = nil
    }
}

extension IniciadorApple: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credencial = authorization.credential as? ASAuthorizationAppleIDCredential
        let token = credencial?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let codigo = credencial?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            if let token, let codigo {
                responder(.exito(identityToken: token, codigo: codigo))
            } else {
                responder(.error)
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        let cancelado = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in responder(cancelado ? .cancelado : .error) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { ventanaActiva() }
    }
}
