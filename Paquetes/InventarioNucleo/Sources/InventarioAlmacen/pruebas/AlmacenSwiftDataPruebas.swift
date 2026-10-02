import Foundation
import Testing
import InventarioNucleo
import SwiftData
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

        let cambiado = producto.fijandoCantidad(7)
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

    // MARK: Sincronización

    @Test func colaYEstadoSeLeenIgualAlReabrir() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        #expect(try almacen.cargarEstado() == .sinHogar)
        #expect(try almacen.cargarPendientes() == Pendientes())

        var cola = Pendientes()
        let productoId = UUID()
        cola.anotar(categoria: UUID())
        cola.anotar(fijada: CantidadFijada(cantidad: 3, en: instante), producto: productoId)
        cola.anotar(Movimiento(productoId: productoId, cambio: -1, momento: instante))
        let estado = EstadoSincronizacion(hogarId: "hogar-1", revision: 12)
        try almacen.guardar(categorias: [], productos: [], pendientes: cola, estado: estado)

        let reabierto = almacen.reabrir()
        #expect(try reabierto.cargarPendientes() == cola)
        #expect(try reabierto.cargarEstado() == estado)
    }

    @Test func guardarSinColaNoLaToca() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        var cola = Pendientes()
        cola.anotar(categoria: UUID())
        try almacen.guardar(categorias: [], productos: [], pendientes: cola, estado: nil)
        try almacen.guardar(categorias: [Categoria(nombre: "Despensa", creado: instante)], productos: [])
        #expect(try almacen.reabrir().cargarPendientes() == cola)
    }

    @Test func vaciarDejaSoloElEstado() throws {
        let almacen = try AlmacenSwiftData.enMemoria()
        let categoria = Categoria(nombre: "Despensa", creado: instante)
        var cola = Pendientes()
        cola.anotar(categoria: categoria.id)
        try almacen.guardar(categorias: [categoria], productos: [], pendientes: cola, estado: nil)

        try almacen.vaciar(estado: EstadoSincronizacion(hogarId: "hogar-2", revision: 0))

        let reabierto = almacen.reabrir()
        #expect(try reabierto.cargarCategorias().isEmpty)
        #expect(try reabierto.cargarPendientes() == Pendientes())
        #expect(try reabierto.cargarEstado().hogarId == "hogar-2")
    }

    /// Lo que pasa en el iPhone de quien ya usa la app: un fichero de la V1
    /// que se abre con la V2.
    @Test func migraUnFicheroDeLaV1SinPerderNada() throws {
        let carpeta = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let url = carpeta.appending(path: "Inventario.store")

        let categoria = Categoria(nombre: "Despensa", creado: instante)
        let producto = Producto(categoriaId: categoria.id, nombre: "Arroz", cantidad: 3, creado: instante)
        do {
            let v1 = try ModelContainer(
                for: Schema(versionedSchema: EsquemaV1.self),
                configurations: ModelConfiguration(url: url)
            )
            let contexto = ModelContext(v1)
            contexto.insert(CategoriaGuardada(categoria))
            contexto.insert(productoV1(producto))
            try contexto.save()
        }

        let almacen = try AlmacenSwiftData.enFichero(url)
        #expect(try almacen.cargarCategorias() == [categoria])
        #expect(try almacen.cargarProductos() == [producto])
        #expect(try almacen.cargarEstado() == .sinHogar)

        // Y la tabla nueva funciona.
        try almacen.guardar(categorias: [], productos: [], pendientes: nil, estado: EstadoSincronizacion(hogarId: "h", revision: 1))
        #expect(try almacen.reabrir().cargarEstado().hogarId == "h")
    }

    /// La V3 añade la unidad: lo que ya había se cuenta en unidades, y la
    /// unidad nueva se guarda.
    @Test func migraUnFicheroDeLaV2ConLaUnidadPorDefecto() throws {
        let carpeta = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let url = carpeta.appending(path: "Inventario.store")

        let categoria = Categoria(nombre: "Despensa", creado: instante)
        let arroz = Producto(categoriaId: categoria.id, nombre: "Arroz", cantidad: 3, creado: instante)
        do {
            let v2 = try ModelContainer(
                for: Schema(versionedSchema: EsquemaV2.self),
                configurations: ModelConfiguration(url: url)
            )
            let contexto = ModelContext(v2)
            contexto.insert(CategoriaGuardada(categoria))
            contexto.insert(productoV1(arroz))
            contexto.insert(SincronizacionGuardada(hogarId: "h", revision: 7, pendientes: Data()))
            try contexto.save()
        }

        let almacen = try AlmacenSwiftData.enFichero(url)
        #expect(try almacen.cargarProductos() == [arroz])
        #expect(try almacen.cargarProductos().first?.unidad == .unidad)
        #expect(try almacen.cargarEstado().revision == 7)

        var atun = Producto(categoriaId: categoria.id, nombre: "Atún", unidad: .lata, cantidad: 2, creado: instante)
        try almacen.guardar(categorias: [], productos: [atun], pendientes: nil, estado: nil)
        atun.unidad = .paquete
        try almacen.guardar(categorias: [], productos: [atun], pendientes: nil, estado: nil)
        #expect(try almacen.reabrir().cargarProductos().first { $0.id == atun.id }?.unidad == .paquete)
    }

    private func productoV1(_ p: Producto) -> EsquemaV1.ProductoGuardado {
        EsquemaV1.ProductoGuardado(
            id: p.id, categoriaId: p.categoriaId, nombre: p.nombre, cantidad: p.cantidad,
            umbralCompra: p.umbralCompra, autoListaCompra: p.autoListaCompra,
            enListaCompraManual: p.enListaCompraManual, creado: p.creado,
            modificado: p.modificado, borrado: p.borrado
        )
    }
}
