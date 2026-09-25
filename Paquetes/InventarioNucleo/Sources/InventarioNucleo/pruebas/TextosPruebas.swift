import Foundation
import Testing
@testable import InventarioNucleo

/// Los textos que se oyen son contrato: si cambia uno, se cambia aquí y en
/// `docs/textos-interfaz.md`.
@Suite struct TextosPruebas {
    @Test func plurales() {
        #expect(Textos.unidades(0) == "0 unidades")
        #expect(Textos.unidades(1) == "1 unidad")
        #expect(Textos.unidades(2) == "2 unidades")
        #expect(Textos.productos(1) == "1 producto")
        #expect(Textos.productos(12) == "12 productos")
    }

    @Test func filas() {
        let despensa = Categoria(nombre: "Despensa", creado: instante)
        #expect(Textos.filaCategoria(despensa, productos: 1) == "Despensa, 1 producto")
        #expect(Textos.filaProducto(producto("Arroz", cantidad: 5)) == "Arroz, 5 unidades")
        #expect(Textos.filaProducto(producto("Arroz", cantidad: 1)) == "Arroz, 1 unidad, en la lista")
    }

    @Test func filasDeLaCompra() {
        #expect(Textos.filaCompra(producto("Arroz", cantidad: 0), categoria: "Despensa") == "Arroz, agotado, Despensa")
        #expect(Textos.filaCompra(producto("Arroz", cantidad: 2), categoria: "Despensa") == "Arroz, 2 unidades, Despensa")
        #expect(
            Textos.filaCompra(producto("Pan", cantidad: 8, manual: true), categoria: "Despensa")
                == "Pan, 8 unidades, Despensa, añadido a mano"
        )
        #expect(
            Textos.filaCompra(producto("Arroz", cantidad: 3), categoria: "Despensa", repuesto: true)
                == "Arroz, 3 unidades, Despensa, repuesto"
        )
        #expect(Textos.repuesto == "Repuesto")
    }

    @Test func menuAnadirYSelectorDeCategoria() {
        #expect(Textos.Botones.anadir == "Añadir")
        #expect(Textos.Botones.categoria == "Categoría")
        #expect(Textos.Botones.producto == "Producto")
        #expect(Textos.Formulario.categoria == "Categoría")
    }

    @Test func umbral() {
        #expect(Textos.Formulario.umbral(0) == "Cuando no quede ninguna")
        #expect(Textos.Formulario.umbral(1) == "Cuando quede 1 unidad o menos")
        #expect(Textos.Formulario.umbral(2) == "Cuando queden 2 unidades o menos")
    }

    @Test func steppersParaVoiceOver() {
        #expect(Textos.Formulario.etiquetaUnidades == "Unidades")
        #expect(Textos.Formulario.valorUnidades(3) == "3")
        #expect(Textos.Formulario.etiquetaUmbral == "Pasa a la lista con")
        #expect(Textos.Formulario.valorUmbral(0) == "0 unidades")
        #expect(Textos.Formulario.valorUmbral(1) == "1 unidad o menos")
        #expect(Textos.Formulario.valorUmbral(2) == "2 unidades o menos")
    }

    @Test func anuncioDeAjusteSinCambioDeLista() {
        let antes = producto(cantidad: 5)
        let ajustado = antes.ajustandoCantidad(en: 1, ahora: despues)
        #expect(Textos.Anuncios.ajusteCantidad(antes: antes, despues: ajustado, cambio: 1) == "6 unidades")
    }

    @Test func anuncioDeAjusteQueEntraOSaleDeLaLista() {
        let tres = producto(cantidad: 3, umbral: 2)
        let dos = tres.ajustandoCantidad(en: -1, ahora: despues)
        #expect(Textos.Anuncios.ajusteCantidad(antes: tres, despues: dos, cambio: -1) == "2 unidades, añadido a la lista")
        #expect(Textos.Anuncios.ajusteCantidad(antes: dos, despues: tres, cambio: 1) == "3 unidades, fuera de la lista")
    }

    @Test func anuncioDeAjusteManualNoCambiaLaLista() {
        let antes = producto(cantidad: 3, umbral: 2, manual: true)
        let ajustado = antes.ajustandoCantidad(en: -1, ahora: despues)
        #expect(Textos.Anuncios.ajusteCantidad(antes: antes, despues: ajustado, cambio: -1) == "2 unidades")
    }

    @Test func anuncioEnLosLimites() {
        let cero = producto(cantidad: 0)
        #expect(Textos.Anuncios.ajusteCantidad(antes: cero, despues: cero, cambio: -1) == "Ya está en 0")
        let maximo = producto(cantidad: 999)
        #expect(Textos.Anuncios.ajusteCantidad(antes: maximo, despues: maximo, cambio: 1) == "Ya está en 999")
    }

    @Test func anuncioDeListaManual() {
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 9, manual: true)) == "Añadido a la lista")
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 9)) == "Quitado de la lista")
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 2)) == "Sigue en la lista, quedan 2 unidades")
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 1)) == "Sigue en la lista, queda 1 unidad")
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 0)) == "Sigue en la lista, agotado")
        #expect(Textos.Anuncios.listaManual(despues: producto(cantidad: 0, auto: false)) == "Quitado de la lista")
    }

    @Test func anunciosDeCrearGuardarYEliminar() {
        #expect(Textos.Anuncios.productoCreado("Arroz") == "Añadido, Arroz")
        #expect(Textos.Anuncios.categoriaCreada("Despensa") == "Añadida, Despensa")
        #expect(Textos.Anuncios.guardado("Arroz") == "Guardado, Arroz")
        #expect(Textos.Anuncios.productoEliminado("Arroz") == "Eliminado, Arroz")
        #expect(Textos.Anuncios.categoriaEliminada("Despensa", productos: 0) == "Eliminada, Despensa")
        #expect(Textos.Anuncios.categoriaEliminada("Despensa", productos: 1) == "Eliminada, Despensa, con 1 producto")
        #expect(Textos.Anuncios.categoriaEliminada("Despensa", productos: 12) == "Eliminada, Despensa, con 12 productos")
    }

    @Test func confirmaciones() {
        #expect(Textos.Confirmacion.eliminar("Arroz") == "¿Eliminar Arroz?")
        #expect(Textos.Confirmacion.eliminarCategoria(productos: 0) == nil)
        #expect(Textos.Confirmacion.eliminarCategoria(productos: 1) == "También se eliminará su producto.")
        #expect(Textos.Confirmacion.eliminarCategoria(productos: 3) == "También se eliminarán sus 3 productos.")
    }

    @Test func resultadoDeImportar() {
        typealias R = ResultadoImportacion
        let t = Textos.Importacion.self
        #expect(t.titulo(R(categorias: 5, productos: 42)) == "Importadas 5 categorías y 42 productos")
        #expect(t.titulo(R(categorias: 1, productos: 1)) == "Importada 1 categoría y 1 producto")
        #expect(t.titulo(R(categorias: 0, productos: 3)) == "Importados 3 productos")
        #expect(t.titulo(R(categorias: 0, productos: 1)) == "Importado 1 producto")
        #expect(t.titulo(R(categorias: 2, productos: 0)) == "Importadas 2 categorías")
        #expect(t.titulo(R()) == "No había nada nuevo que importar")
        #expect(t.mensaje(R(categorias: 1, productos: 1)) == nil)
        #expect(t.mensaje(R(repetidos: 2)) == "2 ya estaban.")
        #expect(t.mensaje(R(repetidos: 1, noValidos: 1)) == "1 ya estaba. 1 no se pudo importar.")
        #expect(t.mensaje(R(noValidos: 3)) == "3 no se pudieron importar.")
    }

        @Test func erroresDeNombre() {
        #expect(Textos.Errores.nombreCategoria(.vacio) == nil)
        #expect(Textos.Errores.nombreCategoria(.repetido) == "Ya hay una categoría con ese nombre")
        #expect(Textos.Errores.nombreProducto(.repetido, categoria: "Nevera") == "Ya hay un producto con ese nombre en Nevera")
        #expect(Textos.Errores.nombreProducto(.demasiadoLargo(maximo: 100), categoria: "Nevera") == "Máximo 100 letras")
    }
}
