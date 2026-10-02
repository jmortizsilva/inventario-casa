/// Límites de los datos. Los comparten la validación, la importación y, más
/// adelante, el servidor y la app de Android.
public enum Limites {
    public static let largoMaximoNombre = 100
    public static let cantidad = 0...999
    public static let umbralCompra = 0...20
    public static let umbralCompraPorDefecto = 2
    /// Con lo que empieza el formulario de crear: lo normal es dar de alta lo
    /// que se acaba de comprar. Se puede bajar a 0 para apuntar algo que falta.
    public static let cantidadAlCrear = 1
}

extension ClosedRange {
    func acotar(_ valor: Bound) -> Bound {
        Swift.min(Swift.max(valor, lowerBound), upperBound)
    }
}
