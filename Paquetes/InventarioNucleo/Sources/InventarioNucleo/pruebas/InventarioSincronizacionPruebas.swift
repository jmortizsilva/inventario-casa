import Foundation
import Testing
@testable import InventarioNucleo

/// Cómo `Inventario` alimenta la cola y la vacía. Las reglas de la cola en sí
/// están en `SincronizacionPruebas`.
@MainActor
@Suite struct InventarioSincronizacionPruebas {
    let almacen = AlmacenEnMemoria()
    let reloj = RelojDePrueba()
    let inventario: Inventario

    init() throws {
        let reloj = self.reloj
        inventario = Inventario(almacen: almacen, ahora: { reloj.ahora() })
        try inventario.unirAHogar("hogar-1", conservando: true)
    }

    // MARK: Qué se anota

    @Test func sinHogarNoSeAnotaNada() throws {
        let solo = Inventario(almacen: AlmacenEnMemoria(), ahora: { instante })
        let despensa = try solo.crearCategoria(nombre: "Despensa")
        try solo.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 2)
        #expect(solo.pendientes.estaVacia)
    }

    @Test func crearAnotaYLasUnidadesVanFijadas() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 3)

        #expect(inventario.pendientes.categorias == [despensa.id])
        #expect(inventario.pendientes.productos == [arroz.id])
        #expect(inventario.pendientes.fijadas[arroz.id] == CantidadFijada(cantidad: 3, en: arroz.creado))
        // Y queda guardado con el cambio, no solo en memoria.
        #expect(almacen.pendientes == inventario.pendientes)
    }

    @Test func masYMenosSonMovimientosConLoQueCambioDeVerdad() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 0)
        try inventario.ajustarCantidad(arroz.id, en: -1) // en 0 no cambia nada
        try inventario.ajustarCantidad(arroz.id, en: 1)

        let movimientos = Array(inventario.pendientes.movimientos.values)
        #expect(movimientos.map(\.cambio) == [1])
        #expect(movimientos.first?.productoId == arroz.id)
    }

    @Test func editarLasUnidadesLasFija() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 1)
        let editado = try inventario.editarProducto(
            arroz.id, nombre: "Arroz", unidad: .unidad, cantidad: 6, umbralCompra: arroz.umbralCompra, autoListaCompra: true
        )
        let fijada = try #require(inventario.pendientes.fijadas[arroz.id])
        #expect(fijada.cantidad == 6)
        #expect(fijada.en > arroz.creado)
        // Solo cambiaron las unidades, que llevan su hora aparte: el producto no.
        #expect(editado.modificado == arroz.modificado)
    }

    @Test func editarOtraCosaNoTocaLaFijadaAnterior() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 1)
        try inventario.editarProducto(
            arroz.id, nombre: "Arroz largo", unidad: .unidad, cantidad: 1, umbralCompra: arroz.umbralCompra, autoListaCompra: true
        )
        #expect(inventario.pendientes.fijadas[arroz.id]?.en == arroz.creado)
    }

    @Test func borrarUnaCategoriaAnotaSusProductos() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        let lote0 = inventario.loteParaEnviar()
        try inventario.confirmarEnvio(lote0, respuesta: .init(categorias: [], productos: [], rechazados: [], revision: 1))
        #expect(inventario.pendientes.estaVacia)

        try inventario.borrarCategoria(despensa.id)

        #expect(inventario.pendientes.categorias == [despensa.id])
        #expect(inventario.pendientes.productos == [arroz.id])
        #expect(inventario.loteParaEnviar().productos.first?.borrado == true)
    }

    @Test func siNoSeGuardaLaColaNoCambia() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let antes = inventario.pendientes
        almacen.fallarAlGuardar = true
        #expect(throws: ErrorInventario.self) {
            try inventario.crearProducto(nombre: "Arroz", en: despensa.id)
        }
        #expect(inventario.pendientes == antes)
    }

    // MARK: Enviar y recibir

    @Test func unEnvioConfirmadoVaciaLaCola() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 2)
        try inventario.ajustarCantidad(arroz.id, en: 1)
        let enviado = inventario.loteParaEnviar()

        // El servidor aplica todo y devuelve el producto con su cuenta: 2 + 1.
        let definitivo = try #require(inventario.producto(arroz.id))
        let respuesta = Api.RespuestaEnvio(
            categorias: enviado.categorias,
            productos: [Api.Producto(definitivo, fijada: nil).conCantidad(3)],
            rechazados: [],
            revision: 7
        )
        try inventario.confirmarEnvio(enviado, respuesta: respuesta)

        #expect(inventario.pendientes.estaVacia)
        #expect(inventario.producto(arroz.id)?.cantidad == 3)
        // La respuesta a un envío no mueve la revisión: se saltarían cambios de otros.
        #expect(inventario.estado.revision == 0)
    }

    @Test func unToqueDuranteElEnvioNoSePierde() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 2)
        let enviado = inventario.loteParaEnviar()
        try inventario.ajustarCantidad(arroz.id, en: 1) // mientras el envío va y viene

        let respuesta = Api.RespuestaEnvio(
            categorias: enviado.categorias,
            productos: [Api.Producto(try #require(inventario.producto(arroz.id)), fijada: nil).conCantidad(2)],
            rechazados: [],
            revision: 5
        )
        try inventario.confirmarEnvio(enviado, respuesta: respuesta)

        #expect(inventario.pendientes.movimientos.count == 1)
        #expect(inventario.producto(arroz.id)?.cantidad == 3)
    }

    @Test func lasNovedadesMuevenLaRevision() throws {
        try inventario.aplicarNovedades(.init(categorias: [], productos: [], revision: 42, masDisponible: false))
        #expect(inventario.estado.revision == 42)
        #expect(almacen.estado.revision == 42)
    }

    // MARK: Entrar y salir de un hogar

    @Test func alUnirseConservandoTodoEntraEnLaCola() throws {
        let solo = Inventario(almacen: AlmacenEnMemoria(), ahora: { instante })
        let despensa = try solo.crearCategoria(nombre: "Despensa")
        let arroz = try solo.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 4)
        try solo.borrarProducto(try solo.crearProducto(nombre: "Pan", en: despensa.id).id)

        try solo.unirAHogar("hogar-1", conservando: true)

        #expect(solo.estado == EstadoSincronizacion(hogarId: "hogar-1", revision: 0))
        #expect(solo.pendientes.categorias == [despensa.id])
        // Lo borrado no se sube a un hogar que nunca lo tuvo.
        #expect(solo.pendientes.productos == [arroz.id])
        // Con la hora de su último cambio, no la de ahora.
        #expect(solo.pendientes.fijadas[arroz.id] == CantidadFijada(cantidad: 4, en: arroz.modificado))
    }

    @Test func alUnirseSinConservarSeVaciaElIphone() throws {
        try inventario.crearCategoria(nombre: "Despensa")
        try inventario.unirAHogar("hogar-2", conservando: false)

        #expect(inventario.categorias.isEmpty)
        #expect(inventario.pendientes.estaVacia)
        #expect(inventario.estado.hogarId == "hogar-2")
        #expect(almacen.categorias.isEmpty)
    }

    @Test func separarseDejaElInventarioYVaciaLaCola() throws {
        try inventario.crearCategoria(nombre: "Despensa")
        try inventario.separarDelHogar()

        #expect(inventario.categorias.count == 1)
        #expect(inventario.pendientes.estaVacia)
        #expect(!inventario.conHogar)
        #expect(almacen.estado == .sinHogar)
    }

    @Test func alCargarRecuperaColaYEstado() throws {
        try inventario.crearCategoria(nombre: "Despensa")
        let recargado = Inventario(almacen: almacen)
        try recargado.cargar()
        #expect(recargado.pendientes == inventario.pendientes)
        #expect(recargado.estado.hogarId == "hogar-1")
    }
}

extension Api.Producto {
    /// La misma fila con la cantidad que calcularía el servidor.
    func conCantidad(_ cantidad: Int) -> Api.Producto {
        Api.Producto(
            id: id, categoriaId: categoriaId, nombre: nombre, cantidad: cantidad, cantidadFijadaEn: nil,
            umbralCompra: umbralCompra, autoListaCompra: autoListaCompra,
            enListaCompraManual: enListaCompraManual, creado: creado, modificado: modificado, borrado: borrado
        )
    }
}
