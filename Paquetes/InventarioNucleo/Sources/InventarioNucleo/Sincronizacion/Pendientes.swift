import Foundation

/// Un toque de más o menos. El servidor los suma todos, así que si dos
/// personas restan a la vez se restan las dos veces.
public struct Movimiento: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let productoId: UUID
    public let cambio: Int
    public let momento: Date

    public init(id: UUID = UUID(), productoId: UUID, cambio: Int, momento: Date) {
        self.id = id
        self.productoId = productoId
        self.cambio = cambio
        self.momento = momento
    }
}

/// Unidades elegidas desde la ficha o al crear el producto: sustituyen al
/// valor anterior, y los movimientos anteriores a `en` dejan de contar.
public struct CantidadFijada: Codable, Hashable, Sendable {
    public let cantidad: Int
    public let en: Date

    public init(cantidad: Int, en: Date) {
        self.cantidad = cantidad
        self.en = en
    }
}

/// Lo que ha cambiado en el iPhone y aún no ha confirmado el servidor.
///
/// De categorías y productos basta con saber cuáles: se manda su versión
/// actual. De las unidades hay que guardar la operación, porque el servidor
/// no quiere el valor final sino cada movimiento.
public struct Pendientes: Codable, Equatable, Sendable {
    public private(set) var categorias: Set<UUID> = []
    public private(set) var productos: Set<UUID> = []
    public private(set) var fijadas: [UUID: CantidadFijada] = [:]
    public private(set) var movimientos: [UUID: Movimiento] = [:]
    /// Categorías y productos recuperados con «Deshacer»: los únicos que el
    /// servidor deja volver después de borrados.
    public private(set) var restaurar: Set<UUID> = []

    public init() {}

    enum CodingKeys: String, CodingKey { case categorias, productos, fijadas, movimientos, restaurar }

    /// A mano para que una cola guardada antes de existir `restaurar` se siga
    /// leyendo: si no, quien actualiza la app con cambios sin enviar los perdería.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categorias = try c.decode(Set<UUID>.self, forKey: .categorias)
        productos = try c.decode(Set<UUID>.self, forKey: .productos)
        fijadas = try c.decode([UUID: CantidadFijada].self, forKey: .fijadas)
        movimientos = try c.decode([UUID: Movimiento].self, forKey: .movimientos)
        restaurar = try c.decodeIfPresent(Set<UUID>.self, forKey: .restaurar) ?? []
    }

    public var estaVacia: Bool { cuantos == 0 }

    /// Para «{n} cambios sin enviar». Cada toque de más o menos cuenta uno.
    public var cuantos: Int { categorias.count + productos.count + movimientos.count }

    public mutating func anotar(categoria id: UUID) {
        categorias.insert(id)
    }

    public mutating func anotar(producto id: UUID) {
        productos.insert(id)
    }

    /// Una fijación nueva sustituye a la anterior sin enviar: solo cuenta la última.
    public mutating func anotar(fijada: CantidadFijada, producto id: UUID) {
        productos.insert(id)
        fijadas[id] = fijada
    }

    public mutating func anotar(_ movimiento: Movimiento) {
        movimientos[movimiento.id] = movimiento
    }

    public mutating func anotar(restaurar id: UUID) {
        restaurar.insert(id)
    }

    public func movimientos(de productoId: UUID) -> [Movimiento] {
        movimientos.values.filter { $0.productoId == productoId }
    }

    mutating func quitar(categoria id: UUID) { categorias.remove(id) }
    mutating func quitar(producto id: UUID) { productos.remove(id) }
    mutating func quitar(fijada id: UUID) { fijadas[id] = nil }
    mutating func quitar(movimiento id: UUID) { movimientos[id] = nil }
    mutating func quitar(restaurar id: UUID) { restaurar.remove(id) }
}
