import Foundation
import Testing
@testable import InventarioNucleo

@Suite struct BusquedaPruebas {
    let despensa = UUID()

    private func productos(_ nombres: String...) -> [Producto] {
        nombres.map { Producto(categoriaId: despensa, nombre: $0, creado: instante) }
    }

    private func nombres(_ texto: String, en lista: [Producto]) -> [String] {
        Busqueda.productos(texto, en: lista).map(\.nombre)
    }

    @Test func mismoNombreSinMayusculasNiTildes() {
        let lista = productos("Limón", "Leche entera", "Leche")
        #expect(nombres("LIMON", en: lista) == ["Limón"])
        // Con uno que se llama igual, no se ofrecen los que solo lo contienen.
        #expect(nombres("leche", en: lista) == ["Leche"])
    }

    @Test func singularYPlural() {
        let lista = productos("Huevo", "Limones", "Pan", "Leche")
        #expect(nombres("huevos", en: lista) == ["Huevo"])
        #expect(nombres("limón", en: lista) == ["Limones"])
        #expect(nombres("panes", en: lista) == ["Pan"])
        #expect(nombres("leches", en: lista) == ["Leche"])
    }

    @Test func variosQueContienenLoDicho() {
        let lista = productos("Leche semidesnatada", "Leche entera", "Aceite")
        #expect(nombres("leche", en: lista) == ["Leche entera", "Leche semidesnatada"])
        #expect(nombres("entera leche", en: lista) == ["Leche entera"])
    }

    @Test func laEnieNoSeConfunde() {
        let lista = productos("Piña", "Pina colada")
        #expect(nombres("piña", en: lista) == ["Piña"])
    }

    @Test func sinCoincidenciasOVacio() {
        let lista = productos("Arroz")
        #expect(nombres("lentejas", en: lista).isEmpty)
        #expect(nombres("   ", en: lista).isEmpty)
    }

    @Test func loBorradoNoSeEncuentra() {
        var sal = Producto(categoriaId: despensa, nombre: "Sal", creado: instante)
        sal.borrado = instante
        #expect(Busqueda.productos("sal", en: [sal]).isEmpty)
    }

    @Test func categorias() {
        let lista = [
            Categoria(nombre: "Baño", creado: instante),
            Categoria(nombre: "Despensa", creado: instante),
        ]
        #expect(Busqueda.categorias("bano", en: lista).isEmpty, "La eñe no es una ene")
        #expect(Busqueda.categorias("DESPENSA", en: lista).map(\.nombre) == ["Despensa"])
    }

    // MARK: Textos de Siri

    @Test func textosDeSiri() {
        let leche = Producto(categoriaId: despensa, nombre: "Leche", cantidad: 5, creado: instante)
        #expect(Textos.Siri.resultado(leche) == "Leche, 5 unidades")
        let agotada = Producto(categoriaId: despensa, nombre: "Leche", cantidad: 0, creado: instante)
        #expect(Textos.Siri.resultado(agotada) == "Leche, 0 unidades, en la lista")
        #expect(Textos.Siri.creado("Leche", en: "Despensa") == "Creado, Leche en Despensa")
        #expect(Textos.Siri.confirmarEliminar("Leche", de: "Despensa") == "¿Elimino Leche de Despensa?")
        #expect(Textos.Siri.eliminado("Leche") == "Eliminado, Leche")
        #expect(Textos.Siri.noEliminado("Leche") == "No se ha eliminado Leche")
        #expect(
            Textos.Siri.variasCategorias(["Nevera grande", "Nevera pequeña"])
                == "Hay varias categorías así: Nevera grande y Nevera pequeña. Dilo con el nombre entero."
        )
        #expect(Textos.Siri.noEncontrado("  leche ", en: "Casa") == "No encuentro leche en Casa.")
        #expect(Textos.Siri.noEncontrado("leche", en: nil) == "No encuentro leche.")
    }

    @Test func pantallaSiri() {
        #expect(AccionVoz.allCases.map(Textos.Siri.titulo) == [
            "Crear producto", "Añadir unidades", "Quitar unidades",
            "Cambiar la cantidad", "Consultar un producto", "Eliminar producto",
        ])
        #expect(AccionVoz.allCases.map(Textos.Siri.fraseSugerida) == [
            "Nuevo producto", "He comprado", "He gastado", "Cambiar cantidad", "Cuánto queda", "Eliminar producto",
        ])
        #expect(Textos.Siri.frase("Nuevo producto") == "«Nuevo producto»")
        #expect(Textos.Siri.sinFrase == "Sin frase")
        #expect(Textos.Siri.pie == "Elige una frase para cada acción y díselo a Siri tal cual.")
    }
}
