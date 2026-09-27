import Foundation
import Testing
@testable import InventarioNucleo

@MainActor
@Suite struct DeshacerPruebas {
    let almacen = AlmacenEnMemoria()
    let reloj = RelojDePrueba()
    let inventario: Inventario

    init() throws {
        let reloj = self.reloj
        inventario = Inventario(almacen: almacen, ahora: { reloj.ahora() })
        try inventario.unirAHogar("hogar-1", conservando: true)
    }

    @Test func deshacerUnProducto() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 3)
        try inventario.borrarProducto(arroz.id)
        #expect(inventario.ultimaEliminacion?.nombre == "Arroz")

        let recuperado = try inventario.deshacerEliminacion()

        #expect(recuperado == .producto(arroz))
        #expect(inventario.producto(arroz.id)?.cantidad == 3)
        #expect(inventario.ultimaEliminacion == nil)
        #expect(inventario.pendientes.restaurar == [arroz.id])
        #expect(inventario.loteParaEnviar().productos.first?.restaurar == true)
    }

    @Test func deshacerUnaCategoriaDevuelveSusProductos() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        let pan = try inventario.crearProducto(nombre: "Pan", en: despensa.id)
        try inventario.borrarCategoria(despensa.id)
        #expect(inventario.categorias.isEmpty)

        try inventario.deshacerEliminacion()

        #expect(inventario.categorias.map(\.nombre) == ["Despensa"])
        let vueltos = Set(inventario.productos(en: despensa.id).map(\.id))
        #expect(vueltos == [arroz.id, pan.id])
        let lote = inventario.loteParaEnviar()
        #expect(lote.categorias.first?.restaurar == true)
        #expect(lote.productos.allSatisfy { $0.restaurar == true })
    }

    @Test func otroCambioCierraElDeshacer() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        try inventario.borrarProducto(arroz.id)
        try inventario.crearCategoria(nombre: "Nevera")
        #expect(inventario.ultimaEliminacion == nil)
        #expect(try inventario.deshacerEliminacion() == nil)
    }

    @Test func loQueLlegaSincronizandoNoCierraElDeshacer() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        try inventario.borrarProducto(arroz.id)
        try inventario.aplicarNovedades(.init(categorias: [], productos: [], revision: 3, masDisponible: false))
        #expect(inventario.ultimaEliminacion?.nombre == "Arroz")
    }

    @Test func unaBajadaNoVuelveABorrarLoRecuperado() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        try inventario.borrarProducto(arroz.id)
        let borrado = Api.Producto(try #require(almacen.productos[arroz.id]), fijada: nil)
        try inventario.deshacerEliminacion()

        // Antes de enviar lo recuperado, llega del servidor la versión borrada.
        try inventario.aplicarNovedades(.init(categorias: [], productos: [borrado], revision: 4, masDisponible: false))

        #expect(inventario.producto(arroz.id) != nil)
    }

    @Test func alConfirmarSeQuitaLaMarca() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        try inventario.borrarProducto(arroz.id)
        try inventario.deshacerEliminacion()
        let enviado = inventario.loteParaEnviar()
        try inventario.confirmarEnvio(enviado, respuesta: .init(categorias: [], productos: [], rechazados: [], revision: 5))
        #expect(inventario.pendientes.restaurar.isEmpty)
        #expect(inventario.pendientes.estaVacia)
    }

    /// Lo que guardó la versión anterior: la cola de ahora codificada y sin
    /// el campo nuevo. (JSONEncoder guarda los diccionarios con clave UUID
    /// como listas, no como objetos: escribirla a mano no sirve.)
    @Test func unaColaGuardadaAntesDeDeshacerSeSigueLeyendo() throws {
        let productoId = UUID()
        var original = Pendientes()
        original.anotar(fijada: CantidadFijada(cantidad: 2, en: instante), producto: productoId)
        original.anotar(Movimiento(productoId: productoId, cambio: 1, momento: despues))
        var campos = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        campos["restaurar"] = nil
        let antigua = try JSONSerialization.data(withJSONObject: campos)

        let cola = try JSONDecoder().decode(Pendientes.self, from: antigua)

        #expect(cola == original)
        #expect(cola.restaurar.isEmpty)
    }

    @Test func textos() {
        #expect(Textos.Anuncios.productoEliminado("Leche") == "Eliminado, Leche. Agita para deshacer.")
        #expect(Textos.Anuncios.categoriaEliminada("Despensa", productos: 3) == "Eliminada, Despensa, con 3 productos. Agita para deshacer.")
        #expect(Textos.Anuncios.categoriaEliminada("Despensa", productos: 0) == "Eliminada, Despensa. Agita para deshacer.")
        #expect(Textos.Deshacer.boton == "Deshacer")
        #expect(Textos.Deshacer.accion("Leche") == "Eliminar Leche")
        #expect(Textos.Deshacer.etiqueta("Leche") == "Deshacer, eliminar Leche")
        #expect(Textos.Deshacer.productoRecuperado("Leche") == "Recuperado, Leche")
        #expect(Textos.Deshacer.categoriaRecuperada("Despensa", productos: 1) == "Recuperada, Despensa, con 1 producto")
        #expect(Textos.Deshacer.categoriaRecuperada("Despensa", productos: 0) == "Recuperada, Despensa")
    }
}
