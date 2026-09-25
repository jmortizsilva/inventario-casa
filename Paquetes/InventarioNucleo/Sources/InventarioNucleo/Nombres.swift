import Foundation

public enum ErrorNombre: Error, Equatable, Sendable {
    case vacio
    case demasiadoLargo(maximo: Int)
    case repetido
}

public enum Nombres {
    private static let espanol = Locale(identifier: "es_ES")

    /// Quita los espacios de los extremos y deja uno solo entre palabras.
    public static func limpiar(_ texto: String) -> String {
        texto
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Clave para detectar repetidos: sin mayúsculas ni tildes, pero con la eñe.
    /// No se usa `.diacriticInsensitive` sobre el texto entero porque convierte
    /// la ñ en n, y «Año» y «ano» pasarían por el mismo nombre.
    public static func clave(_ texto: String) -> String {
        var resultado = ""
        for caracter in limpiar(texto).lowercased() {
            if caracter == "ñ" {
                resultado.append(caracter)
            } else {
                resultado += String(caracter).folding(options: .diacriticInsensitive, locale: nil)
            }
        }
        return resultado
    }

    /// Devuelve el nombre limpio si es válido. `existentes` son los nombres de
    /// las demás categorías, o de los demás productos de la misma categoría,
    /// sin contar el que se está editando ni los borrados.
    public static func validar(
        _ texto: String,
        existentes: some Sequence<String>
    ) -> Result<String, ErrorNombre> {
        let limpio = limpiar(texto)
        if limpio.isEmpty {
            return .failure(.vacio)
        }
        if limpio.count > Limites.largoMaximoNombre {
            return .failure(.demasiadoLargo(maximo: Limites.largoMaximoNombre))
        }
        let claveNueva = clave(limpio)
        if existentes.contains(where: { clave($0) == claveNueva }) {
            return .failure(.repetido)
        }
        return .success(limpio)
    }

    /// Orden alfabético español: la ñ va después de la n, las tildes y las
    /// mayúsculas no separan, y los números se comparan por su valor
    /// («Pilas 2» antes que «Pilas 10»).
    public static func vaAntes(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .numeric], range: nil, locale: espanol)
            == .orderedAscending
    }
}
