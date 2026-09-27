import Foundation

/// El enlace de las invitaciones: `https://inventario.jmortiz.es/unirse/<código>`.
/// Es una dirección normal y no un esquema propio: las apps de mensajes la
/// muestran pulsable, sin la app abre una página del servidor, y la app de
/// Android podrá recibir la misma.
public enum EnlaceInvitacion {
    public static let dominio = "inventario.jmortiz.es"

    public static func url(codigo: String) -> URL {
        URL(string: "https://\(dominio)/unirse/\(codigo)")!
    }

    /// El código de un enlace de invitación, o nil si no lo es. Solo letras y
    /// números: lo demás no puede ser un código, y así nada raro llega a la
    /// pantalla ni al servidor.
    public static func codigo(de url: URL) -> String? {
        guard url.scheme == "https", url.host() == dominio else { return nil }
        let partes = url.pathComponents.filter { $0 != "/" }
        guard partes.count == 2, partes[0] == "unirse" else { return nil }
        let codigo = partes[1].uppercased()
        guard (1...16).contains(codigo.count), codigo.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
        else { return nil }
        return codigo
    }
}
