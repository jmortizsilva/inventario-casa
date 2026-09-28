import Foundation

/// Qué fichero guarda el inventario de cada hogar en el iPhone, y cuál está
/// abierto. Solo decide: abrir y borrar ficheros lo hace la app con lo que
/// dice aquí.
///
/// El inventario que ya había se queda en su fichero (`ficheroOriginal`) y
/// pasa a ser el de su hogar, sin copiar nada: copiar datos de un fichero a
/// otro es donde se pierden. Los demás hogares tienen el suyo, que se crea
/// la primera vez que se abren y se llena desde el servidor.
///
/// Invariante: sin hogares hay un solo fichero, el de sin hogar; con
/// hogares, cada fichero es de uno de ellos.
public struct RegistroHogares: Codable, Equatable, Sendable {
    /// El de siempre, que ya tiene quien usa la app desde antes de haber varios hogares.
    public static let ficheroOriginal = "Inventario"

    /// hogarId → nombre del fichero.
    public private(set) var ficheros: [String: String]
    /// El inventario sin hogar: sin cuenta, o con cuenta y sin ningún hogar.
    public private(set) var sinHogar: String?
    /// El hogar abierto. Nil es el inventario sin hogar.
    public private(set) var activo: String?

    /// Al abrir por primera vez la versión con varios hogares: el fichero que
    /// ya había es del hogar al que estaba unido, si lo estaba.
    public static func inicial(hogarDelFicheroOriginal hogar: String?) -> RegistroHogares {
        if let hogar {
            RegistroHogares(ficheros: [hogar: ficheroOriginal], sinHogar: nil, activo: hogar)
        } else {
            RegistroHogares(ficheros: [:], sinHogar: ficheroOriginal, activo: nil)
        }
    }

    /// El nombre del fichero de un hogar nuevo en el iPhone.
    public static func fichero(de hogar: String) -> String { "Hogar-\(hogar)" }

    public var conHogares: Bool { !ficheros.isEmpty }

    /// El que hay que tener abierto.
    public var ficheroActivo: String {
        activo.flatMap { ficheros[$0] } ?? sinHogar ?? Self.ficheroOriginal
    }

    // MARK: Cambios. Cada uno devuelve los ficheros que hay que borrar.

    /// Entrar en un hogar: crearlo, unirse o abrir uno que aún no estaba en el
    /// iPhone. Sin hogares, el inventario sin hogar pasa a ser suyo (quien
    /// llama decide si conservarlo o vaciarlo); con hogares, se le da uno nuevo.
    /// Devuelve si el fichero es nuevo y hay que llenarlo desde el servidor.
    @discardableResult
    public mutating func entrar(en hogar: String) -> (nuevo: Bool, borrar: [String]) {
        if ficheros[hogar] != nil {
            activo = hogar
            return (false, [])
        }
        if !conHogares, let fichero = sinHogar {
            ficheros[hogar] = fichero
            sinHogar = nil
            activo = hogar
            return (false, [])
        }
        ficheros[hogar] = Self.fichero(de: hogar)
        activo = hogar
        return (true, [])
    }

    /// Cambiar a un hogar que ya está en el registro. Si no está, no hace nada.
    public mutating func cambiar(a hogar: String) {
        if ficheros[hogar] != nil { activo = hogar }
    }

    /// Salir para siempre de un hogar. Si quedan otros, su fichero se borra y
    /// se abre `siguiente` (o el primero que quede). Si era el único, su
    /// inventario se queda en el iPhone como inventario sin hogar.
    public mutating func salir(de hogar: String, siguiente: String? = nil) -> [String] {
        guard let fichero = ficheros.removeValue(forKey: hogar) else { return [] }
        guard conHogares else {
            sinHogar = fichero
            activo = nil
            return []
        }
        if activo == hogar {
            activo = siguiente.flatMap { ficheros[$0] != nil ? $0 : nil } ?? ficheros.keys.sorted().first
        }
        return [fichero]
    }

    /// Cerrar sesión o eliminar la cuenta: se queda el inventario del hogar
    /// abierto, como inventario sin hogar, y los demás se borran del iPhone.
    public mutating func cerrarSesion() -> [String] {
        guard conHogares else { return [] }
        let queda = ficheroActivo
        let borrar = ficheros.values.filter { $0 != queda }.sorted()
        ficheros = [:]
        sinHogar = queda
        activo = nil
        return borrar
    }

    /// Con la lista de hogares que da el servidor: los que ya no están (lo
    /// sacaron, o salió desde otro dispositivo) se tratan como una salida.
    public mutating func quitarLosQueNoEstan(en hogares: [String]) -> [String] {
        let fuera = ficheros.keys.filter { !hogares.contains($0) }.sorted()
        var borrar: [String] = []
        for hogar in fuera {
            borrar += salir(de: hogar, siguiente: hogares.first { ficheros[$0] != nil })
        }
        return borrar
    }
}
