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

/// Un fichero de `pruebas-compartidas/`, en la raíz del repositorio. Se lee
/// por ruta: el simulador ve el disco del Mac.
func rutaCompartida(_ nombre: String, desde fichero: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: fichero)
    // pruebas → InventarioNucleo → Sources → paquete → Paquetes → raíz
    for _ in 0..<6 { url = url.deletingLastPathComponent() }
    return url.appending(path: "pruebas-compartidas/\(nombre)")
}
