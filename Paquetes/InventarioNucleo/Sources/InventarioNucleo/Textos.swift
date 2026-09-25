/// Todo lo que se ve o se oye en la app. Revisado en `docs/textos-interfaz.md`:
/// si cambia un texto, se cambian el documento y las pruebas a la vez.
public enum Textos {

    // MARK: Plurales

    public static func unidades(_ n: Int) -> String {
        n == 1 ? "1 unidad" : "\(n) unidades"
    }

    public static func productos(_ n: Int) -> String {
        n == 1 ? "1 producto" : "\(n) productos"
    }

    // MARK: Pestañas y títulos

    public enum Pestanas {
        public static let inventario = "Inventario"
        public static let compra = "Compra"
        public static let ajustes = "Ajustes"
    }

    public enum Titulos {
        public static let inventario = "Inventario"
        public static let listaCompra = "Lista de la compra"
        public static let ajustes = "Ajustes"
        public static let nuevaCategoria = "Nueva categoría"
        public static let cambiarNombre = "Cambiar nombre"
        public static let nuevoProducto = "Nuevo producto"
        public static let manual = "Manual"
    }

    // MARK: Botones y acciones

    public enum Botones {
        public static let anadirCategoria = "Añadir categoría"
        public static let anadirProducto = "Añadir producto"
        public static let cambiarNombre = "Cambiar nombre"
        public static let eliminar = "Eliminar"
        public static let aumentarCantidad = "Aumentar cantidad"
        public static let disminuirCantidad = "Disminuir cantidad"
        public static let anadirALista = "Añadir a la lista"
        public static let quitarDeLista = "Quitar de la lista"
        public static let guardar = "Guardar"
        public static let cancelar = "Cancelar"
        public static let cerrar = "Cerrar"
        public static let aceptar = "Aceptar"
        public static let reintentar = "Reintentar"
        public static let manual = "Manual"
    }

    // MARK: Filas

    public static func filaCategoria(_ categoria: Categoria, productos n: Int) -> String {
        "\(categoria.nombre), \(productos(n))"
    }

    public static func filaProducto(_ producto: Producto) -> String {
        var texto = "\(producto.nombre), \(unidades(producto.cantidad))"
        if ListaCompra.incluye(producto) {
            texto += ", en la lista"
        }
        return texto
    }

    public static func filaCompra(_ producto: Producto, categoria: String) -> String {
        let estado = producto.cantidad == 0 ? agotado.lowercased() : unidades(producto.cantidad)
        var texto = "\(producto.nombre), \(estado), \(categoria)"
        if producto.enListaCompraManual {
            texto += ", añadido a mano"
        }
        return texto
    }

    public static let agotado = "Agotado"

    // MARK: Listas vacías

    public enum Vacio {
        public static let categorias = "No hay categorías"
        public static func productos(en categoria: String) -> String {
            "No hay productos en \(categoria)"
        }
        public static let listaCompra = "No falta nada"
    }

    // MARK: Formularios

    public enum Formulario {
        public static let nombre = "Nombre"
        public static func unidades(_ n: Int) -> String {
            "Unidades: \(n)"
        }
        public static let listaAutomatica = "Añadir a la lista cuando queden pocas"

        /// Lo que lee VoiceOver en los Stepper: etiqueta y valor por separado,
        /// para que el número no se oiga dos veces («Unidades: 3, 3»).
        public static let etiquetaUnidades = "Unidades"
        public static func valorUnidades(_ n: Int) -> String { "\(n)" }
        public static let etiquetaUmbral = "Pasa a la lista con"
        public static func valorUmbral(_ n: Int) -> String {
            switch n {
            case 0: "0 unidades"
            case 1: "1 unidad o menos"
            default: "\(n) unidades o menos"
            }
        }

        public static func umbral(_ n: Int) -> String {
            switch n {
            case 0: "Cuando no quede ninguna"
            case 1: "Cuando quede 1 unidad o menos"
            default: "Cuando queden \(n) unidades o menos"
            }
        }
    }

    public static func version(_ numero: String) -> String {
        "Versión \(numero)"
    }

    // MARK: Anuncios

    /// Solo se llaman después de que el cambio se haya guardado.
    public enum Anuncios {
        /// Tras aumentar o disminuir. Si no cambió nada es porque estaba en un
        /// límite, y se dice en lugar de callar.
        public static func ajusteCantidad(antes: Producto, despues: Producto, cambio: Int) -> String {
            guard despues.cantidad != antes.cantidad else {
                let limite = cambio < 0 ? Limites.cantidad.lowerBound : Limites.cantidad.upperBound
                return "Ya está en \(limite)"
            }
            let texto = unidades(despues.cantidad)
            switch (ListaCompra.incluye(antes), ListaCompra.incluye(despues)) {
            case (false, true): return texto + ", añadido a la lista"
            case (true, false): return texto + ", fuera de la lista"
            default: return texto
            }
        }

        /// Tras añadir o quitar a mano. Un producto quitado a mano puede seguir
        /// en la lista por tener pocas unidades, y hay que decirlo.
        public static func listaManual(despues: Producto) -> String {
            if despues.enListaCompraManual {
                return "Añadido a la lista"
            }
            guard ListaCompra.incluye(despues) else {
                return "Quitado de la lista"
            }
            switch despues.cantidad {
            case 0: return "Sigue en la lista, agotado"
            case 1: return "Sigue en la lista, queda 1 unidad"
            default: return "Sigue en la lista, quedan \(despues.cantidad) unidades"
            }
        }

        public static func productoCreado(_ nombre: String) -> String { "Añadido, \(nombre)" }
        public static func categoriaCreada(_ nombre: String) -> String { "Añadida, \(nombre)" }
        public static func guardado(_ nombre: String) -> String { "Guardado, \(nombre)" }
        public static func productoEliminado(_ nombre: String) -> String { "Eliminado, \(nombre)" }

        public static func categoriaEliminada(_ nombre: String, productos n: Int) -> String {
            n == 0 ? "Eliminada, \(nombre)" : "Eliminada, \(nombre), con \(productos(n))"
        }
    }

    // MARK: Confirmaciones

    public enum Confirmacion {
        public static func eliminar(_ nombre: String) -> String { "¿Eliminar \(nombre)?" }

        public static func eliminarCategoria(productos n: Int) -> String? {
            switch n {
            case 0: nil
            case 1: "También se eliminará su producto."
            default: "También se eliminarán sus \(n) productos."
            }
        }
    }

    // MARK: Errores

    public enum Errores {
        public static func nombreCategoria(_ error: ErrorNombre) -> String? {
            nombre(error, repetido: "Ya hay una categoría con ese nombre")
        }

        public static func nombreProducto(_ error: ErrorNombre, categoria: String) -> String? {
            nombre(error, repetido: "Ya hay un producto con ese nombre en \(categoria)")
        }

        /// Nombre vacío no tiene texto: Guardar está desactivado en ese caso.
        private static func nombre(_ error: ErrorNombre, repetido: String) -> String? {
            switch error {
            case .vacio: nil
            case .demasiadoLargo(let maximo): "Máximo \(maximo) letras"
            case .repetido: repetido
            }
        }

        public static let noGuardadoTitulo = "No se ha guardado"
        public static let noGuardadoMensaje = "No se pudo escribir en el móvil. Todo sigue como estaba."
        public static let noLeido = "No se pudo leer el inventario"
    }

    // MARK: Importación

    public enum Importacion {
        public static let boton = "Importar datos"
        public static let noImportadoTitulo = "No se ha importado"
        public static let archivoNoValido = "El archivo no es una exportación del inventario."
        public static let nadaNuevo = "No había nada nuevo que importar"

        /// «Importadas 5 categorías y 42 productos». El participio concuerda
        /// con lo primero que se nombra.
        public static func titulo(_ r: ResultadoImportacion) -> String {
            switch (r.categorias, r.productos) {
            case (0, 0):
                return nadaNuevo
            case (0, let p):
                return "\(p == 1 ? "Importado" : "Importados") \(Textos.productos(p))"
            case (let c, 0):
                return "\(c == 1 ? "Importada" : "Importadas") \(categorias(c))"
            case (let c, let p):
                return "\(c == 1 ? "Importada" : "Importadas") \(categorias(c)) y \(Textos.productos(p))"
            }
        }

        /// Lo que no se importó, o nil si se importó todo.
        public static func mensaje(_ r: ResultadoImportacion) -> String? {
            var partes: [String] = []
            if r.repetidos > 0 {
                partes.append(r.repetidos == 1 ? "1 ya estaba." : "\(r.repetidos) ya estaban.")
            }
            if r.noValidos > 0 {
                partes.append(r.noValidos == 1 ? "1 no se pudo importar." : "\(r.noValidos) no se pudieron importar.")
            }
            return partes.isEmpty ? nil : partes.joined(separator: " ")
        }

        private static func categorias(_ n: Int) -> String {
            n == 1 ? "1 categoría" : "\(n) categorías"
        }
    }

    // MARK: Manual

    public struct Apartado: Sendable, Equatable {
        public let titulo: String
        public let texto: String
    }

    public static let manual: [Apartado] = [
        Apartado(
            titulo: "Categorías y productos",
            texto: "En Inventario, Añadir categoría crea una categoría. Dentro de ella, Añadir producto crea un producto con sus unidades."
        ),
        Apartado(
            titulo: "Cambiar las unidades",
            texto: "Con los botones de más y menos de cada producto, o desde su ficha. Con VoiceOver, con las acciones Aumentar cantidad y Disminuir cantidad del rotor."
        ),
        Apartado(
            titulo: "Lista de la compra",
            texto: "Un producto entra solo en la lista cuando le quedan las unidades que marca su ficha, o menos, y sale al reponerlo. También se puede añadir o quitar a mano. Si no quieres que entre solo, desactiva \u{201C}Añadir a la lista cuando queden pocas\u{201D} en su ficha."
        ),
        Apartado(
            titulo: "Eliminar",
            texto: "Eliminar una categoría elimina también sus productos."
        ),
    ]
}
