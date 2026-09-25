import Foundation
import Testing
@testable import InventarioNucleo

@Suite struct ModeloPruebas {
    @Test func valoresPorDefecto() {
        let p = Producto(categoriaId: UUID(), nombre: "Leche", creado: instante)
        #expect(p.cantidad == 0)
        #expect(p.umbralCompra == 2)
        #expect(p.autoListaCompra)
        #expect(!p.enListaCompraManual)
        #expect(p.modificado == instante)
        #expect(!p.estaBorrado)
    }

    @Test func acotaLosValoresAlCrear() {
        let alto = producto(cantidad: 5000, umbral: 50)
        #expect(alto.cantidad == 999)
        #expect(alto.umbralCompra == 20)
        let bajo = producto(cantidad: -3, umbral: -1)
        #expect(bajo.cantidad == 0)
        #expect(bajo.umbralCompra == 0)
    }

    @Test func ajustarCantidad() {
        let p = producto(cantidad: 5).ajustandoCantidad(en: 1, ahora: despues)
        #expect(p.cantidad == 6)
        #expect(p.modificado == despues)
    }

    @Test func noBajaDeCeroNiCuentaComoCambio() {
        let original = producto(cantidad: 0)
        let p = original.ajustandoCantidad(en: -1, ahora: despues)
        #expect(p == original)
    }

    @Test func noPasaDelMaximo() {
        let original = producto(cantidad: 999)
        #expect(original.ajustandoCantidad(en: 1, ahora: despues) == original)
    }

    @Test func fijarCantidadYUmbral() {
        let p = producto(cantidad: 5)
            .fijandoCantidad(2, ahora: despues)
            .fijandoUmbralCompra(25, ahora: despues)
        #expect(p.cantidad == 2)
        #expect(p.umbralCompra == 20)
        #expect(p.modificado == despues)
    }

    @Test func borrarCategoriaBorraSoloSusProductos() {
        let categoria = Categoria(nombre: "Despensa", creado: instante)
        let otra = UUID()
        var yaBorrado = producto("Sal", categoriaId: categoria.id)
        yaBorrado.borrado = instante

        let (borrada, productos) = categoria.borrando(
            conProductos: [
                producto("Arroz", categoriaId: categoria.id),
                producto("Leche", categoriaId: otra),
                producto("Pasta", categoriaId: categoria.id),
                yaBorrado,
            ],
            ahora: despues
        )

        #expect(borrada.borrado == despues)
        #expect(borrada.modificado == despues)
        #expect(productos.map(\.nombre) == ["Arroz", "Pasta"])
        #expect(productos.allSatisfy { $0.borrado == despues && $0.modificado == despues })
    }

    @Test func seCodificaYDecodificaIgual() throws {
        let p = producto(manual: true)
        let datos = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(Producto.self, from: datos) == p)
    }
}
