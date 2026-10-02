import Foundation

public struct Producto: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var categoriaId: UUID
    public var nombre: String
    public var unidad: Unidad
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
        unidad: Unidad = .unidad,
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
        self.unidad = unidad
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
    private enum CodingKeys: String, CodingKey {
        case id, categoriaId, nombre, unidad, cantidad, umbralCompra
        case autoListaCompra, enListaCompraManual, creado, modificado, borrado
    }

    /// `unidad` puede faltar: las exportaciones anteriores a ella no la llevan.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            categoriaId: try c.decode(UUID.self, forKey: .categoriaId),
            nombre: try c.decode(String.self, forKey: .nombre),
            unidad: try c.decodeIfPresent(Unidad.self, forKey: .unidad) ?? .unidad,
            cantidad: try c.decode(Int.self, forKey: .cantidad),
            umbralCompra: try c.decode(Int.self, forKey: .umbralCompra),
            autoListaCompra: try c.decode(Bool.self, forKey: .autoListaCompra),
            enListaCompraManual: try c.decode(Bool.self, forKey: .enListaCompraManual),
            creado: try c.decode(Date.self, forKey: .creado),
            modificado: try c.decode(Date.self, forKey: .modificado),
            borrado: try c.decodeIfPresent(Date.self, forKey: .borrado)
        )
    }
}

extension Producto {
    /// Para los botones de más y menos. Si el valor no cambia (ya está en 0 o
    /// en el máximo), el producto se devuelve intacto.
    public func ajustandoCantidad(en cambio: Int) -> Producto {
        fijandoCantidad(cantidad + cambio)
    }

    /// Para la pantalla de edición, donde se elige el valor final.
    ///
    /// No toca `modificado`: las unidades se sincronizan con su propia hora
    /// (movimientos y fijaciones). Moviéndolo, un producto al que solo se le
    /// había dado a «+» parecía recién editado y le ganaba al servidor a
    /// cambios de otra persona, incluido un borrado: así volvió «Legía.»
    /// tras borrarla desde otro iPhone.
    public func fijandoCantidad(_ nueva: Int) -> Producto {
        let acotada = Limites.cantidad.acotar(nueva)
        guard acotada != cantidad else { return self }
        var copia = self
        copia.cantidad = acotada
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
