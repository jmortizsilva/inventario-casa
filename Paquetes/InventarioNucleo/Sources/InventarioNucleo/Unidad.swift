/// En qué se cuenta un producto. Es el nombre de lo que se cuenta, no una
/// medida: la cantidad sigue siendo un número entero («3 latas»). Se descartó
/// contar en kilos o litros con decimales porque nadie pesa lo que gasta, y
/// habría cambiado la sincronización, que suma y resta enteros.
///
/// El valor en bruto es lo que se guarda y viaja al servidor: no se cambia.
public enum Unidad: String, CaseIterable, Hashable, Sendable {
    case unidad
    case lata
    case paquete
    case botella
    case brick
    case bote
    case bolsa
    case caja
    case rollo

    public var singular: String {
        switch self {
        case .unidad: "unidad"
        case .lata: "lata"
        case .paquete: "paquete"
        case .botella: "botella"
        case .brick: "brick"
        case .bote: "bote"
        case .bolsa: "bolsa"
        case .caja: "caja"
        case .rollo: "rollo"
        }
    }

    public var plural: String {
        switch self {
        case .unidad: "unidades"
        case .lata: "latas"
        case .paquete: "paquetes"
        case .botella: "botellas"
        case .brick: "bricks"
        case .bote: "botes"
        case .bolsa: "bolsas"
        case .caja: "cajas"
        case .rollo: "rollos"
        }
    }

    /// Para concordar: «Cuando no quede ninguna» (lata), «ninguno» (paquete).
    public var esFemenina: Bool {
        switch self {
        case .unidad, .lata, .botella, .bolsa, .caja: true
        case .paquete, .brick, .bote, .rollo: false
        }
    }
}

extension Unidad: Codable {
    /// Un valor desconocido (de una versión más nueva de la app o del
    /// servidor) se lee como unidad en lugar de dejar el producto sin leer.
    public init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = Unidad(rawValue: valor) ?? .unidad
    }
}
