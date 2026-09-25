import Foundation

/// Archivo de exportación del inventario. Lo genera el script de
/// `scripts/exportar-firestore` y lo lee la importación de la app.
public struct Exportacion: Codable, Equatable, Sendable {
    public static let formatoEsperado = "inventario-casa"
    public static let versionActual = 1

    public let formato: String
    public let version: Int
    public let categorias: [Categoria]
    public let productos: [Producto]

    public init(categorias: [Categoria], productos: [Producto]) {
        formato = Self.formatoEsperado
        version = Self.versionActual
        self.categorias = categorias
        self.productos = productos
    }

    /// Fechas en ISO 8601 sin fracciones de segundo, que es lo que entiende
    /// `.iso8601` de Foundation.
    public static func leer(_ datos: Data) throws(ErrorImportacion) -> Exportacion {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        guard let exportacion = try? decodificador.decode(Exportacion.self, from: datos),
              exportacion.formato == formatoEsperado,
              exportacion.version == versionActual
        else {
            throw .archivoNoValido
        }
        return exportacion
    }

    public func escribir() throws -> Data {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try codificador.encode(self)
    }
}

public enum ErrorImportacion: Error, Equatable, Sendable {
    case archivoNoValido
}

public struct ResultadoImportacion: Equatable, Sendable {
    public var categorias = 0
    public var productos = 0
    /// Productos que ya existían con el mismo nombre en su categoría.
    public var repetidos = 0
    /// Nombres vacíos o demasiado largos, y productos sin categoría.
    public var noValidos = 0

    public init(categorias: Int = 0, productos: Int = 0, repetidos: Int = 0, noValidos: Int = 0) {
        self.categorias = categorias
        self.productos = productos
        self.repetidos = repetidos
        self.noValidos = noValidos
    }
}
