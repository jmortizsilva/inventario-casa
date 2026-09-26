import AuthenticationServices
import InventarioConexion
import InventarioNucleo
import SwiftUI

/// Apple y Google, con el error debajo. En la bienvenida y en Ajustes.
struct BotonesInicioSesion: View {
    @Environment(Cuenta.self) private var cuenta
    @Environment(\.colorScheme) private var esquema
    @State private var nonce = Login.nonceParaApple()
    @State private var error: String?
    @State private var entrando = false
    var alIniciar: () -> Void = {}

    var body: some View {
        Group {
            if cuenta.usaBotonAppleDelSistema {
                SignInWithAppleButton(.signIn) { solicitud in
                    nonce = Login.nonceParaApple()
                    solicitud.requestedScopes = [.email]
                    solicitud.nonce = nonce.resumen
                } onCompletion: { resultado in
                    let apple = Self.traducir(resultado)
                    ejecutar { await cuenta.completarConApple(apple, nonce: nonce) }
                }
                .signInWithAppleButtonStyle(esquema == .dark ? .white : .black)
                .frame(minHeight: 44)
                .accessibilityHint(Textos.Sesion.pistaIniciar)
            } else {
                Button(Textos.Sesion.iniciarConApple) {
                    ejecutar { await cuenta.iniciarConApple() }
                }
                .accessibilityHint(Textos.Sesion.pistaIniciar)
            }
            Button(Textos.Sesion.iniciarConGoogle) {
                ejecutar { await cuenta.iniciarConGoogle() }
            }
            .accessibilityHint(Textos.Sesion.pistaIniciar + ". " + Textos.Sesion.pistaGoogle)
            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .disabled(entrando)
    }

    private func ejecutar(_ accion: @escaping () async -> String?) {
        entrando = true
        error = nil
        Task {
            let fallo = await accion()
            entrando = false
            error = fallo
            if let fallo {
                anunciar(fallo)
            } else if cuenta.conSesion {
                alIniciar()
            }
        }
    }

    private static func traducir(_ resultado: Result<ASAuthorization, any Error>) -> ResultadoApple {
        switch resultado {
        case .success(let autorizacion):
            let credencial = autorizacion.credential as? ASAuthorizationAppleIDCredential
            guard let token = credencial?.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let codigo = credencial?.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) })
            else { return .error }
            return .exito(identityToken: token, codigo: codigo)
        case .failure(let error):
            return (error as? ASAuthorizationError)?.code == .canceled ? .cancelado : .error
        }
    }
}
