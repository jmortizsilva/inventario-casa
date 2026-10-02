import Foundation

/// Las acciones que se pueden guardar con «Añadir a Siri», en el orden en
/// que salen en Ajustes.
public enum AccionVoz: CaseIterable, Sendable {
    case crearProducto
    case anadirUnidades
    case quitarUnidades
    case cambiarCantidad
    case consultarProducto
    case eliminarProducto
}

/// Lo que Siri dice al usar las acciones de la app. Revisados en
/// `docs/textos-interfaz.md`, apartado «Siri».
///
/// Las frases de los atajos, los títulos de las acciones y las preguntas por
/// cada dato no están aquí: Apple las lee al compilar y tienen que ser
/// literales en el código de la app (`InventarioCasa/Siri`). La excepción es
/// la pregunta por la cantidad, que depende del envase del producto.
extension Textos {
    public enum Siri {
        // MARK: Pantalla «Siri» en Ajustes

        public static let titulo = "Siri"
        public static let sinFrase = "Sin frase"
        public static let pie = "Elige una frase para cada acción y díselo a Siri tal cual."

        /// Debajo de la acción, la frase que se eligió.
        public static func frase(_ frase: String) -> String { "«\(frase)»" }

        public static func titulo(_ accion: AccionVoz) -> String {
            switch accion {
            case .crearProducto: "Crear producto"
            case .anadirUnidades: "Añadir unidades"
            case .quitarUnidades: "Quitar unidades"
            case .cambiarCantidad: "Cambiar la cantidad"
            case .consultarProducto: "Consultar un producto"
            case .eliminarProducto: "Eliminar producto"
            }
        }

        /// La que propone la hoja de «Añadir a Siri»; cada persona la cambia.
        public static func fraseSugerida(_ accion: AccionVoz) -> String {
            switch accion {
            case .crearProducto: "Nuevo producto"
            case .anadirUnidades: "He comprado"
            case .quitarUnidades: "He gastado"
            case .cambiarCantidad: "Cambiar cantidad"
            case .consultarProducto: "Cuánto queda"
            case .eliminarProducto: "Eliminar producto"
            }
        }

        // MARK: Lo que dice Siri

        public static let apartado = Apartado(
            titulo: "Siri",
            texto: "En Ajustes, Siri, pulsa cada acción y guarda la frase que quieras decir, por ejemplo \u{201C}He comprado\u{201D}. Después dísela a Siri tal cual. Siri pregunta lo que falte, y puedes contestar el producto y las unidades de una vez: \u{201C}5 unidades de leche\u{201D}. Si no te entiende una palabra, dila de otra forma. Todo va al hogar abierto."
        )

        /// Al consultar: lo mismo que dice la fila del producto en la app.
        public static func resultado(_ producto: Producto) -> String {
            Textos.filaProducto(producto)
        }

        /// Lo que pregunta Siri cuando falta la cantidad, con el envase del
        /// producto: «¿Cuántas latas?», «¿Cuántos paquetes hay?» (`hay`, al
        /// cambiar la cantidad).
        public static func preguntaCantidad(_ unidad: Unidad, hay: Bool = false) -> String {
            "¿\(unidad.esFemenina ? "Cuántas" : "Cuántos") \(unidad.plural)\(hay ? " hay" : "")?"
        }

        /// Tras añadir, quitar o cambiar la cantidad: las unidades y, si toca,
        /// qué ha pasado con la lista de la compra.
        public static func cambio(antes: Producto, despues: Producto) -> String {
            let unidades = "\(despues.nombre), \(Textos.cantidad(despues.cantidad, despues.unidad))"
            switch (ListaCompra.incluye(antes), ListaCompra.incluye(despues)) {
            case (false, true): return "\(unidades). Añadido a la lista de la compra."
            case (true, true): return "\(unidades). Sigue en la lista de la compra."
            case (true, false): return "\(unidades). Quitado de la lista de la compra."
            case (false, false): return "\(unidades)."
            }
        }

        public static func creado(_ producto: String, en categoria: String) -> String {
            "Creado, \(producto) en \(categoria)"
        }

        public static func confirmarEliminar(_ producto: String, de categoria: String) -> String {
            "¿Elimino \(producto) de \(categoria)?"
        }

        public static func eliminado(_ producto: String) -> String {
            "Eliminado, \(producto)"
        }

        /// Si a «¿Elimino…?» se contesta que no.
        public static func noEliminado(_ producto: String) -> String {
            "No se ha eliminado \(producto)"
        }

        /// Lo dicho encaja con varias: «Nevera» con «Nevera grande» y «Nevera pequeña».
        public static func variasCategorias(_ nombres: [String]) -> String {
            "Hay varias categorías así: \(enumerar(nombres)). Dilo con el nombre entero."
        }

        /// Sin hogar (sin cuenta o sin hogar todavía), no se nombra ninguno.
        public static func noEncontrado(_ texto: String, en hogar: String?) -> String {
            let limpio = Nombres.limpiar(texto)
            guard let hogar else { return "No encuentro \(limpio)." }
            return "No encuentro \(limpio) en \(hogar)."
        }
    }
}
