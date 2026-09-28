import Foundation

/// Lo que Siri dice al usar las acciones de la app. Revisados en
/// `docs/textos-interfaz.md`, apartado «Siri».
///
/// Las frases de los atajos, los títulos de las acciones y las preguntas por
/// cada dato no están aquí: Apple las lee al compilar y tienen que ser
/// literales en el código de la app (`InventarioCasa/Siri`).
extension Textos {
    public enum Siri {
        public static let apartado = Apartado(
            titulo: "Siri",
            texto: "Di, por ejemplo, \u{201C}Añade leche en Inventario Casa\u{201D}, \u{201C}He gastado leche en Inventario Casa\u{201D}, \u{201C}Consulta leche en Inventario Casa\u{201D} o \u{201C}Crea un producto en Inventario Casa\u{201D}. Siri pregunta lo que falte. Todo va al hogar abierto. Crear y eliminar piden desbloquear el iPhone. En la app Atajos puedes hacerte frases propias con estas acciones."
        )

        /// Tras añadir, quitar, cambiar la cantidad o consultar: lo mismo que
        /// dice la fila del producto en la app.
        public static func resultado(_ producto: Producto) -> String {
            Textos.filaProducto(producto)
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

        /// Sin hogar (sin cuenta o sin hogar todavía), no se nombra ninguno.
        public static func noEncontrado(_ texto: String, en hogar: String?) -> String {
            let limpio = Nombres.limpiar(texto)
            guard let hogar else { return "No encuentro \(limpio)." }
            return "No encuentro \(limpio) en \(hogar)."
        }
    }
}
