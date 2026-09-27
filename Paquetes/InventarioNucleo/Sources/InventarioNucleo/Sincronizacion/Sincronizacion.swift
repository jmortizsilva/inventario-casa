import Foundation

/// Las decisiones de la sincronización, sin red ni base de datos: qué se
/// manda, qué queda confirmado y cómo se mezcla lo que llega con lo que hay.
/// Quién llama al servidor y cuándo vive en la app.
public enum Sincronizacion {
    /// Lo que admite el servidor en un envío (`MAXIMO_POR_LOTE`).
    public static let maximoPorLote = 1000

    // MARK: Unidades

    /// Las unidades que se ven mientras hay cambios sin confirmar: lo que dice
    /// el servidor más los movimientos que aún no le han llegado. Sin esto, un
    /// «+1» recién tocado desaparecería de la pantalla con cualquier bajada
    /// que llegue antes de enviarlo.
    ///
    /// Si hay unidades fijadas sin enviar, mandan ellas: el servidor las
    /// aplicará y solo sumará los movimientos posteriores. Es la misma cuenta
    /// que `calcularCantidad` del servidor, acotada al final.
    public static func cantidadVisible(
        servidor: Int,
        fijada: CantidadFijada?,
        movimientos: [Movimiento]
    ) -> Int {
        let total: Int
        if let fijada {
            total = movimientos
                .filter { $0.momento.milisegundos > fijada.en.milisegundos }
                .reduce(fijada.cantidad) { $0 + $1.cambio }
        } else {
            total = movimientos.reduce(servidor) { $0 + $1.cambio }
        }
        return Limites.cantidad.acotar(total)
    }

    // MARK: Enviar

    /// El siguiente envío: categorías, después productos y después
    /// movimientos, hasta `maximo`.
    ///
    /// El orden importa. El servidor rechaza un producto cuya categoría no
    /// conoce, y un movimiento de un producto que no conoce, y lo rechazado
    /// sale de la cola para siempre. Por eso no se empieza a llenar un tipo
    /// hasta que el anterior ha entrado entero: lo que no quepa va en el
    /// siguiente envío, detrás de lo que necesita.
    public static func lote(
        _ pendientes: Pendientes,
        categorias: [UUID: Categoria],
        productos: [UUID: Producto],
        maximo: Int = maximoPorLote
    ) -> Api.Lote {
        var lote = Api.Lote()

        let categoriasPendientes = pendientes.categorias.compactMap { categorias[$0] }
        for categoria in categoriasPendientes.sorted(by: { $0.id.enTexto < $1.id.enTexto }) {
            guard lote.cuantos < maximo else { return lote }
            lote.categorias.append(Api.Categoria(categoria, restaurar: pendientes.restaurar.contains(categoria.id)))
        }

        let productosPendientes = pendientes.productos.compactMap { productos[$0] }
        for producto in productosPendientes.sorted(by: { $0.id.enTexto < $1.id.enTexto }) {
            guard lote.cuantos < maximo else { return lote }
            lote.productos.append(Api.Producto(
                producto, fijada: pendientes.fijadas[producto.id], restaurar: pendientes.restaurar.contains(producto.id)
            ))
        }

        let movimientos = pendientes.movimientos.values.sorted {
            ($0.momento, $0.id.enTexto) < ($1.momento, $1.id.enTexto)
        }
        for movimiento in movimientos {
            guard lote.cuantos < maximo else { return lote }
            lote.movimientos.append(Api.Movimiento(movimiento))
        }
        return lote
    }

    /// La cola después de que el servidor haya contestado a `enviado`.
    ///
    /// Sale lo que se mandó, también lo rechazado: el servidor no lo va a
    /// aceptar por mucho que se reenvíe, y dejarlo dentro repetiría el envío
    /// en cada sincronización, para siempre.
    ///
    /// Pero solo sale si no ha vuelto a cambiar mientras el envío iba y
    /// venía. Si alguien toca el nombre durante esos segundos, esa versión
    /// nueva no la ha visto el servidor y tiene que seguir en la cola.
    public static func confirmar(
        _ pendientes: Pendientes,
        enviado: Api.Lote,
        categorias: [UUID: Categoria],
        productos: [UUID: Producto]
    ) -> Pendientes {
        var cola = pendientes
        for enviada in enviado.categorias {
            guard let id = UUID(uuidString: enviada.id) else { continue }
            if categorias[id].map({ Api.Categoria($0, restaurar: cola.restaurar.contains(id)) == enviada }) ?? true {
                cola.quitar(categoria: id)
                cola.quitar(restaurar: id)
            }
        }
        // El producto y sus unidades fijadas salen juntos, y solo si lo que se
        // mandaría ahora es exactamente lo que se mandó. Si algo cambió, se
        // queda todo: reenviar la misma fijación no hace nada en el servidor,
        // que solo acepta una más reciente que la que tiene.
        for enviado in enviado.productos {
            guard let id = UUID(uuidString: enviado.id) else { continue }
            let actual = productos[id].map {
                Api.Producto($0, fijada: cola.fijadas[id], restaurar: cola.restaurar.contains(id))
            }
            if actual.map({ $0 == enviado }) ?? true {
                cola.quitar(producto: id)
                cola.quitar(fijada: id)
                cola.quitar(restaurar: id)
            }
        }
        for movimiento in enviado.movimientos {
            if let id = UUID(uuidString: movimiento.id) {
                cola.quitar(movimiento: id)
            }
        }
        return cola
    }

    // MARK: Recibir

    /// Mezcla lo que llega del servidor, sea la respuesta a un envío o una
    /// bajada de novedades. Devuelve solo lo que cambia en el iPhone.
    ///
    /// Lo que sigue en la cola no se pisa: el iPhone tiene una versión que el
    /// servidor todavía no ha visto, y ya decidirá él cuál gana cuando le
    /// llegue. Las unidades sí se recalculan siempre, con `cantidadVisible`.
    ///
    /// Lo que llega con un identificador que no es un UUID se ignora: no lo
    /// ha podido crear ningún cliente de esta app.
    public static func fusionar(
        categorias recibidas: [Api.Categoria],
        productos recibidos: [Api.Producto],
        en locales: (categorias: [UUID: Categoria], productos: [UUID: Producto]),
        pendientes: Pendientes
    ) -> (categorias: [Categoria], productos: [Producto]) {
        var categorias: [Categoria] = []
        for recibida in recibidas {
            // Un borrado entra aunque haya cambios en la cola: eliminar es
            // definitivo y el servidor no va a aceptar esos cambios. Salvo lo
            // recuperado con «Deshacer», que va a volver en cuanto se envíe.
            guard let id = UUID(uuidString: recibida.id),
                  !pendientes.restaurar.contains(id),
                  recibida.borrado || !pendientes.categorias.contains(id)
            else { continue }
            let local = locales.categorias[id]
            let nueva = Categoria(
                id: id,
                nombre: recibida.nombre,
                creado: Date(milisegundos: recibida.creado),
                modificado: Date(milisegundos: recibida.modificado),
                borrado: borrado(recibida.borrado, local: local?.borrado, modificado: recibida.modificado)
            )
            if nueva != local { categorias.append(nueva) }
        }

        var productos: [Producto] = []
        for recibido in recibidos {
            guard let id = UUID(uuidString: recibido.id),
                  let categoriaId = UUID(uuidString: recibido.categoriaId)
            else { continue }
            let local = locales.productos[id]
            let cantidad = cantidadVisible(
                servidor: recibido.cantidad ?? 0,
                fijada: pendientes.fijadas[id],
                movimientos: pendientes.movimientos(de: id)
            )

            let nuevo: Producto
            if pendientes.restaurar.contains(id) { continue }
            if pendientes.productos.contains(id), !recibido.borrado, let local {
                nuevo = local.fijandoCantidad(cantidad)
            } else {
                nuevo = Producto(
                    id: id,
                    categoriaId: categoriaId,
                    nombre: recibido.nombre,
                    cantidad: cantidad,
                    umbralCompra: recibido.umbralCompra,
                    autoListaCompra: recibido.autoListaCompra,
                    enListaCompraManual: recibido.enListaCompraManual,
                    creado: Date(milisegundos: recibido.creado),
                    modificado: Date(milisegundos: recibido.modificado),
                    borrado: borrado(recibido.borrado, local: local?.borrado, modificado: recibido.modificado)
                )
            }
            if nuevo != local { productos.append(nuevo) }
        }
        return (categorias, productos)
    }

    /// El servidor solo dice si está borrado. Se conserva la fecha que ya
    /// había en el iPhone para no marcarlo como cambiado sin motivo.
    private static func borrado(_ estaBorrado: Bool, local: Date?, modificado: Int64) -> Date? {
        guard estaBorrado else { return nil }
        return local ?? Date(milisegundos: modificado)
    }
}
