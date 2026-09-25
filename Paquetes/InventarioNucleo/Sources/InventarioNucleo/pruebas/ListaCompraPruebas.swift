import Foundation
import Testing
@testable import InventarioNucleo

struct CasoListaCompra: Decodable, CustomTestStringConvertible, Sendable {
    let caso: String
    let cantidad: Int
    let umbralCompra: Int
    let autoListaCompra: Bool
    let enListaCompraManual: Bool
    let borrado: Bool
    let enLista: Bool

    var testDescription: String { caso }
}

private struct FicheroCasos: Decodable {
    let casos: [CasoListaCompra]
}

private func cargarCasos() throws -> [CasoListaCompra] {
    let url = try #require(
        Bundle.module.url(forResource: "casos-lista-compra", withExtension: "json", subdirectory: "Recursos")
    )
    return try JSONDecoder().decode(FicheroCasos.self, from: Data(contentsOf: url)).casos
}

@Suite struct ListaCompraPruebas {
    @Test(arguments: try cargarCasos())
    func reglaDeLosCasosCompartidos(_ caso: CasoListaCompra) {
        let p = Producto(
            categoriaId: UUID(),
            nombre: "Producto",
            cantidad: caso.cantidad,
            umbralCompra: caso.umbralCompra,
            autoListaCompra: caso.autoListaCompra,
            enListaCompraManual: caso.enListaCompraManual,
            creado: instante,
            borrado: caso.borrado ? instante : nil
        )
        #expect(ListaCompra.incluye(p) == caso.enLista)
    }

    @Test func ordenaPorCantidadYDespuesPorNombre() {
        let lista = ListaCompra.productos(de: [
            producto("Zumo", cantidad: 1),
            producto("ñame", cantidad: 0),
            producto("Nata", cantidad: 0),
            producto("Arroz", cantidad: 2),
            producto("azúcar", cantidad: 1),
            producto("Pan", cantidad: 9),
        ])
        #expect(lista.map(\.nombre) == ["Nata", "ñame", "azúcar", "Zumo", "Arroz"])
    }

    @Test func mismoNombreEnDosCategoriasTieneOrdenEstable() {
        let a = producto("Leche", cantidad: 0)
        let b = producto("Leche", cantidad: 0)
        #expect(ListaCompra.productos(de: [a, b]) == ListaCompra.productos(de: [b, a]))
    }
}
