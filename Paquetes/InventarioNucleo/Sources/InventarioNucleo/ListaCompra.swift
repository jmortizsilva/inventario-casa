import Foundation

public enum ListaCompra {
    /// Un producto está en la lista si se añadió a mano, o si tiene activada la
    /// lista automática y le quedan tantas unidades como su umbral o menos.
    public static func incluye(_ producto: Producto) -> Bool {
        guard !producto.estaBorrado else { return false }
        if producto.enListaCompraManual {
            return true
        }
        return producto.autoListaCompra && producto.cantidad <= producto.umbralCompra
    }

    /// Los productos de la lista, primero los que tienen menos unidades y,
    /// con la misma cantidad, por nombre.
    public static func productos(de todos: [Producto]) -> [Producto] {
        todos
            .filter(incluye)
            .sorted { a, b in
                if a.cantidad != b.cantidad {
                    return a.cantidad < b.cantidad
                }
                if Nombres.clave(a.nombre) != Nombres.clave(b.nombre) {
                    return Nombres.vaAntes(a.nombre, b.nombre)
                }
                // Mismo nombre en categorías distintas: el id fija el orden
                // para que la lista no baile entre un refresco y otro.
                return a.id.uuidString < b.id.uuidString
            }
    }
}
