import Foundation
import Testing
@testable import InventarioNucleo

/// `exportacion-prueba.json` trae: Despensa (Arroz, arroz repetido, Aceite),
/// «  Nevera » (Leche con valores fuera de rango, añadida a mano), una
/// categoría borrada con un producto borrado, una categoría sin nombre y un
/// producto cuya categoría no existe.
@MainActor
@Suite struct ImportacionPruebas {
    let almacen = AlmacenEnMemoria()
    let inventario: Inventario

    init() {
        inventario = Inventario(almacen: almacen, ahora: { despues })
    }

    private func cargar(_ nombre: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: nombre, withExtension: "json", subdirectory: "Recursos"))
        return try Data(contentsOf: url)
    }

    @Test func leeElArchivo() throws {
        let exportacion = try Exportacion.leer(try cargar("exportacion-prueba"))
        #expect(exportacion.categorias.count == 4)
        #expect(exportacion.productos.count == 6)
        // El archivo es anterior a la unidad: sin ella, se cuenta en unidades.
        #expect(exportacion.productos.allSatisfy { $0.unidad == .unidad })
    }

    @Test func laUnidadSeExportaYSeLee() throws {
        let atun = producto("Atún", unidad: .lata)
        let leida = try Exportacion.leer(try Exportacion(categorias: [], productos: [atun]).escribir())
        #expect(leida.productos.first?.unidad == .lata)
    }

    @Test func unaUnidadDesconocidaSeLeeComoUnidad() throws {
        let datos = try Exportacion(categorias: [], productos: [producto("Agua", unidad: .botella)]).escribir()
        let texto = try #require(String(data: datos, encoding: .utf8))
            .replacingOccurrences(of: "\"botella\"", with: "\"garrafa\"")
        let leida = try Exportacion.leer(Data(texto.utf8))
        #expect(leida.productos.first?.unidad == .unidad)
    }

    @Test func importarConservaLaUnidad() throws {
        let despensa = Categoria(nombre: "Despensa", creado: instante)
        let atun = producto("Atún", unidad: .lata, categoriaId: despensa.id)
        try inventario.importar(Exportacion(categorias: [despensa], productos: [atun]))
        #expect(inventario.productos(en: try #require(inventario.categorias.first).id).first?.unidad == .lata)
    }

    /// `exportacion-script.json` lo generó `scripts/exportar-firestore/convertir.js`.
    /// Si el script cambia el formato, hay que regenerarlo y esta prueba dice si
    /// la app lo sigue entendiendo.
    @Test func leeLoQueGeneraElScript() throws {
        let exportacion = try Exportacion.leer(try cargar("exportacion-script"))
        let resultado = try inventario.importar(exportacion)
        #expect(resultado == ResultadoImportacion(categorias: 2, productos: 2))
        let despensa = try #require(inventario.categorias.first)
        #expect(despensa.creado == ISO8601DateFormatter().date(from: "2025-03-01T10:00:00Z"))
        #expect(inventario.listaCompra.map(\.nombre) == ["Leche"])
    }

    /// `exportacion-real.json` es el hogar real exportado de Firestore en
    /// septiembre de 2026. Trae productos duplicados (la migración de datos
    /// antiguos de la app de Expo se ejecutó dos veces) y una categoría vacía.
    @Test func importaElHogarReal() throws {
        let resultado = try inventario.importar(Exportacion.leer(cargar("exportacion-real")))

        #expect(resultado == ResultadoImportacion(categorias: 6, productos: 15, repetidos: 8))
        #expect(inventario.categorias.map(\.nombre) == [
            "Congelados", "Conservas", "Hogar", "Lácteos", "Legumbres", "Salsas y aderezos",
        ])
        let legumbres = try #require(inventario.categorias.first { $0.nombre == "Legumbres" })
        #expect(inventario.productos(en: legumbres.id).map(\.nombre) == [
            "Garbanzos", "Judias", "Lentejas", "Macarrones Macarrones",
        ])
        #expect(Textos.Importacion.titulo(resultado) == "Importadas 6 categorías y 15 productos")
        #expect(Textos.Importacion.mensaje(resultado) == "8 ya estaban.")
    }

    @Test(arguments: [
        "{}",
        "no es json",
        #"{"formato":"otra-app","version":1,"categorias":[],"productos":[]}"#,
        #"{"formato":"inventario-casa","version":2,"categorias":[],"productos":[]}"#,
    ])
    func rechazaLoQueNoEsUnaExportacion(_ texto: String) {
        #expect(throws: ErrorImportacion.archivoNoValido) {
            try Exportacion.leer(Data(texto.utf8))
        }
    }

    @Test func escribirYLeerDaLoMismo() throws {
        let categoria = Categoria(nombre: "Despensa", creado: instante)
        let exportacion = Exportacion(
            categorias: [categoria],
            productos: [producto(categoriaId: categoria.id)]
        )
        #expect(try Exportacion.leer(exportacion.escribir()) == exportacion)
    }

    @Test func importaEnUnInventarioVacio() throws {
        let resultado = try inventario.importar(Exportacion.leer(cargar("exportacion-prueba")))

        #expect(resultado == ResultadoImportacion(categorias: 2, productos: 3, repetidos: 1, noValidos: 2))
        #expect(inventario.categorias.map(\.nombre) == ["Despensa", "Nevera"])

        let despensa = try #require(inventario.categorias.first)
        #expect(inventario.productos(en: despensa.id).map(\.nombre) == ["Aceite", "Arroz"])

        let nevera = inventario.categorias[1]
        let leche = try #require(inventario.productos(en: nevera.id).first)
        #expect(leche.cantidad == 999)
        #expect(leche.umbralCompra == 20)
        #expect(leche.enListaCompraManual)
        #expect(!leche.autoListaCompra)
        #expect(almacen.vecesGuardado == 1, "Todo de una vez")
    }

    @Test func conservaCreadoYMarcaModificadoAhora() throws {
        try inventario.importar(Exportacion.leer(cargar("exportacion-prueba")))
        let despensa = try #require(inventario.categorias.first)
        let arroz = try #require(inventario.productos(en: despensa.id).first { $0.nombre == "Arroz" })
        #expect(arroz.creado == ISO8601DateFormatter().date(from: "2025-03-01T10:00:00Z"))
        #expect(arroz.modificado == despues)
    }

    @Test func generaIdentificadoresNuevos() throws {
        let exportacion = try Exportacion.leer(cargar("exportacion-prueba"))
        try inventario.importar(exportacion)
        let idsArchivo = Set(exportacion.categorias.map(\.id) + exportacion.productos.map(\.id))
        let idsGuardados = Set(almacen.categorias.keys).union(almacen.productos.keys)
        #expect(idsArchivo.isDisjoint(with: idsGuardados))
    }

    @Test func importarDosVecesNoDuplica() throws {
        let exportacion = try Exportacion.leer(cargar("exportacion-prueba"))
        try inventario.importar(exportacion)
        let guardadosAntes = almacen.vecesGuardado

        let segunda = try inventario.importar(exportacion)

        #expect(segunda == ResultadoImportacion(categorias: 0, productos: 0, repetidos: 4, noValidos: 2))
        #expect(inventario.categorias.count == 2)
        #expect(almacen.vecesGuardado == guardadosAntes, "Sin nada nuevo no se escribe")
    }

    @Test func juntaConCategoriasExistentes() throws {
        let despensa = try inventario.crearCategoria(nombre: "despensa")
        try inventario.crearProducto(nombre: "ARROZ", en: despensa.id)

        let resultado = try inventario.importar(Exportacion.leer(cargar("exportacion-prueba")))

        #expect(resultado.categorias == 1)
        #expect(resultado.repetidos == 2)
        #expect(inventario.categorias.map(\.nombre) == ["despensa", "Nevera"])
        #expect(inventario.productos(en: despensa.id).map(\.nombre) == ["Aceite", "ARROZ"])
    }

    @Test func siFallaElGuardadoNoCambiaNada() throws {
        almacen.fallarAlGuardar = true
        #expect(throws: ErrorInventario.self) {
            try inventario.importar(Exportacion.leer(cargar("exportacion-prueba")))
        }
        #expect(inventario.categorias.isEmpty)
    }

    // MARK: Copia a otro hogar

    @Test func copiaAOtroHogarSinCantidadesNiListaManual() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.crearCategoria(nombre: "Baño")
        let arroz = try inventario.crearProducto(nombre: "Arroz", en: despensa.id, unidad: .paquete, cantidad: 4, umbralCompra: 2)
        try inventario.fijarListaManual(arroz.id, en: true)
        try inventario.borrarProducto(inventario.crearProducto(nombre: "Sal", en: despensa.id).id)

        let otro = Inventario(almacen: AlmacenEnMemoria(), ahora: { despues })
        try otro.unirAHogar("playa", conservando: false)
        try otro.importar(try #require(inventario.copia(.categoriasYProductos)))

        #expect(otro.categorias.map(\.nombre) == ["Baño", "Despensa"])
        let despensaCopiada = try #require(otro.categorias.last)
        #expect(despensaCopiada.id != despensa.id)
        let copiado = try #require(otro.productos(en: despensaCopiada.id).first)
        #expect(otro.productos(en: despensaCopiada.id).count == 1, "Lo borrado no se copia")
        #expect(copiado.id != arroz.id)
        #expect(copiado.cantidad == 0)
        #expect(copiado.umbralCompra == 2)
        #expect(copiado.unidad == .paquete)
        #expect(!copiado.enListaCompraManual)
        #expect(otro.pendientes.categorias.count == 2)
        #expect(otro.pendientes.productos == [copiado.id])
        // El original no cambia.
        #expect(inventario.producto(arroz.id)?.cantidad == 4)
    }

    @Test func copiaSoloLasCategorias() throws {
        let despensa = try inventario.crearCategoria(nombre: "Despensa")
        try inventario.crearProducto(nombre: "Arroz", en: despensa.id)

        let copia = try #require(inventario.copia(.categorias))

        #expect(copia.categorias.map(\.nombre) == ["Despensa"])
        #expect(copia.productos.isEmpty)
    }

    @Test func sinNadaQueCopiarNoHayCopia() throws {
        #expect(inventario.copia(.categoriasYProductos) == nil)
        try inventario.crearCategoria(nombre: "Despensa")
        #expect(inventario.copia(.nada) == nil)
    }
}
