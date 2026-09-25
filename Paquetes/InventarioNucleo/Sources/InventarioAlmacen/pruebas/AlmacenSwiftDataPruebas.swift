import Foundation
import Testing
import InventarioNucleo
@testable import InventarioAlmacen

private let instante = Date(timeIntervalSince1970: 1_750_000_000)

@MainActor
@Suite struct AlmacenSwiftDataPruebas {
    @Test func loGuardadoSeLeeIgualAlReabrir() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        let categoria = Categoria(nombre: "Despensa", creado: instante)
        let producto = Producto(
            categoriaId: categoria.id, nombre: "Arroz", cantidad: 3, umbralCompra: 1,
            autoListaCompra: false, enListaCompraManual: true, creado: instante,
            modificado: instante.addingTimeInterval(5), borrado: instante.addingTimeInterval(9)
        )
        try almacen.guardar(categorias: [categoria], productos: [producto])

        let reabierto = almacen.reabrir()
        #expect(try reabierto.cargarCategorias() == [categoria])
        #expect(try reabierto.cargarProductos() == [producto])
    }

    @Test func guardarDosVecesSustituyeEnLugarDeDuplicar() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        let producto = Producto(categoriaId: UUID(), nombre: "Leche", cantidad: 1, creado: instante)
        try almacen.guardar(categorias: [], productos: [producto])

        let cambiado = producto.fijandoCantidad(7, ahora: instante.addingTimeInterval(60))
        try almacen.guardar(categorias: [], productos: [cambiado])

        #expect(try almacen.reabrir().cargarProductos() == [cambiado])
    }

    @Test func inventarioCompletoSobreSwiftData() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        let inventario = Inventario(almacen: almacen, ahora: { instante })
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 1)
        try inventario.ajustarCantidad(arroz.id, en: 1)
        try inventario.borrarCategoria(despensa.id)

        let recargado = Inventario(almacen: almacen.reabrir(), ahora: { instante })
        try recargado.cargar()
        #expect(recargado.categorias.isEmpty)
        #expect(recargado.listaCompra.isEmpty)
        let guardados = try almacen.reabrir().cargarProductos()
        #expect(guardados.count == 1)
        #expect(guardados.first?.cantidad == 2)
        #expect(guardados.first?.estaBorrado == true)
    }
}
