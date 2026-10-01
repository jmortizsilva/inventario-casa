import Foundation

/// Lo que se contesta a Siri en una sola respuesta: «5 unidades de leche»,
/// «2 latas de atún», «una leche». Separa las unidades del producto para no
/// tener que preguntarlas. Solo cuenta un número al principio, seguido de un
/// espacio: «Pilas 2» o «7up» son nombres.
public enum PeticionVoz {
    public struct Partes: Equatable, Sendable {
        public let unidades: Int?
        public let producto: String

        public init(unidades: Int?, producto: String) {
            self.unidades = unidades
            self.producto = producto
        }
    }

    /// Siri suele escribir los números con cifras, pero no siempre.
    private static let numeros: [String: Int] = [
        "un": 1, "una": 1, "uno": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
        "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10, "once": 11, "doce": 12,
        "quince": 15, "veinte": 20,
    ]

    /// Envases y medidas que se dicen entre el número y el producto: no forman
    /// parte del nombre («2 latas de atún» es atún).
    private static let envases: Set<String> = [
        "unidad", "unidades", "lata", "latas", "paquete", "paquetes", "botella", "botellas",
        "bolsa", "bolsas", "caja", "cajas", "bote", "botes", "brik", "briks", "tarro", "tarros",
    ]

    public static func separar(_ texto: String) -> Partes {
        let limpio = Nombres.limpiar(texto)
        var palabras = limpio.split(separator: " ").map(String.init)
        guard palabras.count >= 2 else { return Partes(unidades: nil, producto: limpio) }

        let primera = Nombres.clave(palabras[0])
        guard let unidades = Int(primera) ?? numeros[primera], unidades > 0 else {
            return Partes(unidades: nil, producto: limpio)
        }
        palabras.removeFirst()
        if palabras.count >= 2, envases.contains(Nombres.clave(palabras[0])) { palabras.removeFirst() }
        if palabras.count >= 2, Nombres.clave(palabras[0]) == "de" { palabras.removeFirst() }
        return Partes(unidades: unidades, producto: palabras.joined(separator: " "))
    }
}
