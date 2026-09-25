import InventarioNucleo

/// Operaciones sobre productos que anuncian su resultado, compartidas por las
/// pantallas de productos y de lista de la compra. Devuelven `false` si no se
/// pudo guardar, para que la pantalla muestre el error.
extension Inventario {
    func ajustarYAnunciar(_ producto: Producto, en cambio: Int) -> Bool {
        do {
            let despues = try ajustarCantidad(producto.id, en: cambio)
            anunciar(Textos.Anuncios.ajusteCantidad(antes: producto, despues: despues, cambio: cambio))
            return true
        } catch {
            return false
        }
    }

    func cambiarListaYAnunciar(_ producto: Producto) -> Bool {
        do {
            let despues = try fijarListaManual(producto.id, en: !producto.enListaCompraManual)
            anunciar(Textos.Anuncios.listaManual(despues: despues))
            return true
        } catch {
            return false
        }
    }

    func eliminarYAnunciar(_ producto: Producto) -> Bool {
        do {
            try borrarProducto(producto.id)
            anunciar(Textos.Anuncios.productoEliminado(producto.nombre))
            return true
        } catch {
            return false
        }
    }
}
