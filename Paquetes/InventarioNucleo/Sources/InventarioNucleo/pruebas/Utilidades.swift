import Foundation
@testable import InventarioNucleo

/// Fecha fija para que las pruebas no dependan del reloj.
let instante = Date(timeIntervalSince1970: 1_750_000_000)
let despues = instante.addingTimeInterval(60)

func producto(
    _ nombre: String = "Leche",
    cantidad: Int = 5,
    umbral: Int = 2,
    auto: Bool = true,
    manual: Bool = false,
    categoriaId: UUID = UUID()
) -> Producto {
    Producto(
        categoriaId: categoriaId,
        nombre: nombre,
        cantidad: cantidad,
        umbralCompra: umbral,
        autoListaCompra: auto,
        enListaCompraManual: manual,
        creado: instante
    )
}
