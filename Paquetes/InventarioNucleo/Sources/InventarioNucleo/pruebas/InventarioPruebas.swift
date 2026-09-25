import Foundation
import Testing
@testable import InventarioNucleo

/// Reloj que avanza un minuto cada vez que se consulta.
@MainActor
final class RelojDePrueba {
    private(set) var actual = instante
    func ahora() -> Date {
        actual = actual.addingTimeInterval(60)
        return actual
    }
}

@MainActor
@Suite struct InventarioPruebas {
    let almacen = AlmacenEnMemoria()
    let reloj = RelojDePrueba()
    let inventario: Inventario

    init() {
        let reloj = self.reloj
        inventario = Inventario(almacen: almacen, ahora: { reloj.ahora() })
    }

    // MARK: Categorías

    @Test func creaYOrdenaCategorias() throws {
        try inventario.crearCategoria(nombre: "  Limpieza ")
        try inventario.crearCategoria(nombre: "baño")
        try inventario.crearCategoria(nombre: "Bebidas")
        #expect(inventario.categorias.map(\.nombre) == ["baño", "Bebidas", "Limpieza"])
        #expect(almacen.categorias.count == 3)
    }

    @Test func rechazaCategoriaRepetida() throws {
        try inventario.crearCategoria(nombre: "Despensa")
        #expect(throws: ErrorInventario.nombre(.repetido)) {
            try inventario.crearCategoria(nombre: "despensa")
        }
    }

    @Test func unaCategoriaBorradaDejaReutilizarSuNombre() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.borrarCategoria(despensa.id)
        try inventario.crearCategoria(nombre: "Despensa")
        #expect(inventario.categorias.count == 1)
    }

    @Test func renombrarACambiarSoloMayusculasSePermite() throws {
        let c = try inventario.crearCategoria(nombre: "despensa")
        let renombrada = try inventario.renombrarCategoria(c.id, a: "Despensa")
        #expect(renombrada.nombre == "Despensa")
        #expect(renombrada.modificado > c.modificado)
    }

    @Test func renombrarAlMismoNombreNoGuarda() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let guardadosAntes = almacen.vecesGuardado
        try inventario.renombrarCategoria(c.id, a: " Despensa ")
        #expect(almacen.vecesGuardado == guardadosAntes)
    }

    @Test func borrarCategoriaQuitaSusProductosDeLaLista() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 0)
        #expect(inventario.listaCompra.count == 1)

        try inventario.borrarCategoria(c.id)

        #expect(inventario.categorias.isEmpty)
        #expect(inventario.productos(en: c.id).isEmpty)
        #expect(inventario.listaCompra.isEmpty)
        #expect(almacen.productos.values.allSatisfy { $0.estaBorrado })
    }

    // MARK: Productos

    @Test func creaProductoConValoresPorDefecto() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id)
        #expect(p.cantidad == 0)
        #expect(p.umbralCompra == 2)
        #expect(inventario.productos(en: c.id) == [p])
    }

    @Test func mismoProductoEnDistintasCategoriasSePermite() throws {
        let nevera = try inventario.crearCategoria(nombre: "Nevera")
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.crearProducto(nombre: "Leche", en: nevera.id)
        try inventario.crearProducto(nombre: "Leche", en: despensa.id)
        #expect(throws: ErrorInventario.nombre(.repetido)) {
            try inventario.crearProducto(nombre: "LECHE", en: nevera.id)
        }
    }

    @Test func noCreaProductoEnCategoriaBorrada() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.borrarCategoria(c.id)
        #expect(throws: ErrorInventario.noEncontrado) {
            try inventario.crearProducto(nombre: "Arroz", en: c.id)
        }
    }

    @Test func ajustarCantidadEnCeroNoGuarda() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 0)
        let guardadosAntes = almacen.vecesGuardado
        let resultado = try inventario.ajustarCantidad(p.id, en: -1)
        #expect(resultado == p)
        #expect(almacen.vecesGuardado == guardadosAntes)
    }

    @Test func ajustarCantidadSacaDeLaLista() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 2)
        #expect(inventario.listaCompra.map(\.id) == [p.id])
        try inventario.ajustarCantidad(p.id, en: 1)
        #expect(inventario.listaCompra.isEmpty)
        #expect(almacen.productos[p.id]?.cantidad == 3)
    }

    @Test func editarProducto() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 5)
        let editado = try inventario.editarProducto(
            p.id, nombre: "Arroz integral", cantidad: 1, umbralCompra: 0, autoListaCompra: false
        )
        #expect(editado.nombre == "Arroz integral")
        #expect(editado.cantidad == 1)
        #expect(editado.umbralCompra == 0)
        #expect(!editado.autoListaCompra)
        #expect(editado.modificado > p.modificado)
        #expect(almacen.productos[p.id] == editado)
    }

    @Test func editarSinCambiosNoGuarda() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 5)
        let guardadosAntes = almacen.vecesGuardado
        try inventario.editarProducto(p.id, nombre: "Arroz ", cantidad: 5, umbralCompra: 2, autoListaCompra: true)
        #expect(almacen.vecesGuardado == guardadosAntes)
    }

    @Test func listaManual() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 10)
        try inventario.fijarListaManual(p.id, en: true)
        #expect(inventario.listaCompra.map(\.id) == [p.id])
        try inventario.fijarListaManual(p.id, en: false)
        #expect(inventario.listaCompra.isEmpty)
    }

    @Test func borrarProducto() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id)
        try inventario.borrarProducto(p.id)
        #expect(inventario.productos(en: c.id).isEmpty)
        #expect(inventario.producto(p.id) == nil)
        #expect(throws: ErrorInventario.noEncontrado) {
            try inventario.ajustarCantidad(p.id, en: 1)
        }
    }

    // MARK: Errores al guardar

    @Test func siFallaElGuardadoLaPantallaNoCambia() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        let p = try inventario.crearProducto(nombre: "Arroz", en: c.id, cantidad: 4)
        almacen.fallarAlGuardar = true

        #expect(throws: ErrorInventario.self) { try inventario.ajustarCantidad(p.id, en: 1) }
        #expect(throws: ErrorInventario.self) { try inventario.crearCategoria(nombre: "Nevera") }
        #expect(throws: ErrorInventario.self) { try inventario.borrarCategoria(c.id) }

        #expect(inventario.producto(p.id)?.cantidad == 4)
        #expect(inventario.categorias.map(\.nombre) == ["Despensa"])
    }

    @Test func cargarLeeLoGuardado() throws {
        let c = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.crearProducto(nombre: "Arroz", en: c.id)
        let otro = Inventario(almacen: almacen)
        try otro.cargar()
        #expect(otro.categorias == inventario.categorias)
        #expect(otro.productos(en: c.id) == inventario.productos(en: c.id))
    }
}
