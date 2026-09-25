import Foundation

public struct Producto: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var categoriaId: UUID
    public var nombre: String
    public private(set) var cantidad: Int
    public private(set) var umbralCompra: Int
    public var autoListaCompra: Bool
    public var enListaCompraManual: Bool
    public let creado: Date
    public var modificado: Date
    /// Borrado lógico: se conserva para que la sincronización sepa qué se borró.
    public var borrado: Date?

    /// Cantidad y umbral se acotan a `Limites`: un valor fuera de rango
    /// (por ejemplo, en datos importados) nunca llega a guardarse.
    public init(
        id: UUID = UUID(),
        categoriaId: UUID,
        nombre: String,
        cantidad: Int = 0,
        umbralCompra: Int = Limites.umbralCompraPorDefecto,
        autoListaCompra: Bool = true,
        enListaCompraManual: Bool = false,
        creado: Date,
        modificado: Date? = nil,
        borrado: Date? = nil
    ) {
        self.id = id
        self.categoriaId = categoriaId
        self.nombre = nombre
        self.cantidad = Limites.cantidad.acotar(cantidad)
        self.umbralCompra = Limites.umbralCompra.acotar(umbralCompra)
        self.autoListaCompra = autoListaCompra
        self.enListaCompraManual = enListaCompraManual
        self.creado = creado
        self.modificado = modificado ?? creado
        self.borrado = borrado
    }

    public var estaBorrado: Bool { borrado != nil }
}

extension Producto {
    /// Para los botones de más y menos. Si el valor no cambia (ya está en 0 o
    /// en el máximo), el producto se devuelve intacto y no cuenta como modificado.
    public func ajustandoCantidad(en cambio: Int, ahora: Date) -> Producto {
        fijandoCantidad(cantidad + cambio, ahora: ahora)
    }

    /// Para la pantalla de edición, donde se elige el valor final.
    public func fijandoCantidad(_ nueva: Int, ahora: Date) -> Producto {
        let acotada = Limites.cantidad.acotar(nueva)
        guard acotada != cantidad else { return self }
        var copia = self
        copia.cantidad = acotada
        copia.modificado = ahora
        return copia
    }

    public func fijandoUmbralCompra(_ nuevo: Int, ahora: Date) -> Producto {
        let acotado = Limites.umbralCompra.acotar(nuevo)
        guard acotado != umbralCompra else { return self }
        var copia = self
        copia.umbralCompra = acotado
        copia.modificado = ahora
        return copia
    }
}
