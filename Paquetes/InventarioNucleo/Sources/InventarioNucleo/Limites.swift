/// Límites de los datos. Los comparten la validación, la importación y, más
/// adelante, el servidor y la app de Android.
public enum Limites {
    public static let largoMaximoNombre = 100
    public static let cantidad = 0...999
    public static let umbralCompra = 0...20
    public static let umbralCompraPorDefecto = 2
}

extension ClosedRange {
    func acotar(_ valor: Bound) -> Bound {
        Swift.min(Swift.max(valor, lowerBound), upperBound)
    }
}
