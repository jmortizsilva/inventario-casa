import SwiftUI
import InventarioNucleo

/// Inventario de ejemplo en memoria para las vistas previas de Xcode.
@MainActor
enum VistaPrevia {
    static func inventario(vacio: Bool = false) -> Inventario {
        let inventario = Inventario(almacen: AlmacenEnMemoria())
        guard !vacio else { return inventario }
        if let despensa = try? inventario.crearCategoria(nombre: "Despensa"),
           let nevera = try? inventario.crearCategoria(nombre: "Nevera") {
            _ = try? inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 3)
            _ = try? inventario.crearProducto(nombre: "Aceite", en: despensa.id, cantidad: 1)
            _ = try? inventario.crearProducto(nombre: "Leche", en: nevera.id, cantidad: 0)
        }
        _ = try? inventario.crearCategoria(nombre: "Limpieza")
        return inventario
    }
}
