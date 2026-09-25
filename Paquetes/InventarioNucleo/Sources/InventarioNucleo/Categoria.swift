import Foundation

public struct Categoria: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var nombre: String
    public let creado: Date
    public var modificado: Date
    /// Borrado lógico: se conserva para que la sincronización sepa qué se borró.
    public var borrado: Date?

    public init(
        id: UUID = UUID(),
        nombre: String,
        creado: Date,
        modificado: Date? = nil,
        borrado: Date? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.creado = creado
        self.modificado = modificado ?? creado
        self.borrado = borrado
    }

    public var estaBorrada: Bool { borrado != nil }
}

extension Categoria {
    /// Borra la categoría y todos sus productos a la vez. Devuelve solo los
    /// productos que han cambiado.
    public func borrando(
        conProductos productos: [Producto],
        ahora: Date
    ) -> (categoria: Categoria, productos: [Producto]) {
        var categoria = self
        categoria.borrado = ahora
        categoria.modificado = ahora

        let productosBorrados = productos
            .filter { $0.categoriaId == id && !$0.estaBorrado }
            .map { producto in
                var copia = producto
                copia.borrado = ahora
                copia.modificado = ahora
                return copia
            }
        return (categoria, productosBorrados)
    }
}
