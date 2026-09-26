import Foundation

/// Las formas JSON del contrato con el servidor (`servidor/docs/CONTRATO-API.md`).
/// Fechas en milisegundos e identificadores en texto, como los manda el servidor.
public enum Api {
    public struct Categoria: Codable, Equatable, Sendable {
        public let id: String
        public let nombre: String
        public let creado: Int64
        public let modificado: Int64
        public let borrado: Bool

        public init(id: String, nombre: String, creado: Int64, modificado: Int64, borrado: Bool) {
            self.id = id
            self.nombre = nombre
            self.creado = creado
            self.modificado = modificado
            self.borrado = borrado
        }
    }

    /// Al subir, `cantidad` y `cantidadFijadaEn` van solo si se fijaron las
    /// unidades desde la ficha o al crear; si no, se omiten y el servidor no
    /// toca la cantidad. Al bajar, `cantidad` es la calculada por el servidor.
    public struct Producto: Codable, Equatable, Sendable {
        public let id: String
        public let categoriaId: String
        public let nombre: String
        public let cantidad: Int?
        public let cantidadFijadaEn: Int64?
        public let umbralCompra: Int
        public let autoListaCompra: Bool
        public let enListaCompraManual: Bool
        public let creado: Int64
        public let modificado: Int64
        public let borrado: Bool

        public init(
            id: String, categoriaId: String, nombre: String, cantidad: Int?, cantidadFijadaEn: Int64?,
            umbralCompra: Int, autoListaCompra: Bool, enListaCompraManual: Bool,
            creado: Int64, modificado: Int64, borrado: Bool
        ) {
            self.id = id
            self.categoriaId = categoriaId
            self.nombre = nombre
            self.cantidad = cantidad
            self.cantidadFijadaEn = cantidadFijadaEn
            self.umbralCompra = umbralCompra
            self.autoListaCompra = autoListaCompra
            self.enListaCompraManual = enListaCompraManual
            self.creado = creado
            self.modificado = modificado
            self.borrado = borrado
        }
    }

    public struct Movimiento: Codable, Equatable, Sendable {
        public let id: String
        public let productoId: String
        public let cambio: Int
        public let momento: Int64

        public init(id: String, productoId: String, cambio: Int, momento: Int64) {
            self.id = id
            self.productoId = productoId
            self.cambio = cambio
            self.momento = momento
        }
    }

    /// Lo que se manda en `POST /sincronizar`.
    public struct Lote: Codable, Equatable, Sendable {
        public var categorias: [Categoria] = []
        public var productos: [Producto] = []
        public var movimientos: [Movimiento] = []

        public init(categorias: [Categoria] = [], productos: [Producto] = [], movimientos: [Movimiento] = []) {
            self.categorias = categorias
            self.productos = productos
            self.movimientos = movimientos
        }

        public var cuantos: Int { categorias.count + productos.count + movimientos.count }
        public var estaVacio: Bool { cuantos == 0 }
    }

    public struct Rechazado: Codable, Equatable, Sendable {
        public let tipo: String
        public let id: String
        public let motivo: String

        public init(tipo: String, id: String, motivo: String) {
            self.tipo = tipo
            self.id = id
            self.motivo = motivo
        }
    }

    /// Lo que responde `POST /sincronizar`: la versión definitiva de todo lo
    /// que se tocó, aunque no sea la que se mandó.
    public struct RespuestaEnvio: Codable, Equatable, Sendable {
        public let categorias: [Categoria]
        public let productos: [Producto]
        public let rechazados: [Rechazado]
        public let revision: Int

        public init(categorias: [Categoria], productos: [Producto], rechazados: [Rechazado], revision: Int) {
            self.categorias = categorias
            self.productos = productos
            self.rechazados = rechazados
            self.revision = revision
        }
    }

    /// Lo que responde `GET /sincronizar`.
    public struct Novedades: Codable, Equatable, Sendable {
        public let categorias: [Categoria]
        public let productos: [Producto]
        public let revision: Int
        public let masDisponible: Bool

        public init(categorias: [Categoria], productos: [Producto], revision: Int, masDisponible: Bool) {
            self.categorias = categorias
            self.productos = productos
            self.revision = revision
            self.masDisponible = masDisponible
        }
    }
}

extension Date {
    /// Redondeado, no truncado. `Date(milisegundos: 1999)` guarda 1,999 s, que
    /// en coma flotante es 1,99899…; truncar daba 1998, y una fecha llegada del
    /// servidor dejaba de ser igual a sí misma al compararla: la cola no se
    /// vaciaba nunca.
    public var milisegundos: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    public init(milisegundos: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milisegundos) / 1000)
    }
}

extension UUID {
    /// En minúsculas, como los genera cualquier otra plataforma. El servidor
    /// compara los identificadores como texto.
    var enTexto: String { uuidString.lowercased() }
}

extension Api.Categoria {
    init(_ categoria: InventarioNucleo.Categoria) {
        self.init(
            id: categoria.id.enTexto,
            nombre: categoria.nombre,
            creado: categoria.creado.milisegundos,
            modificado: categoria.modificado.milisegundos,
            borrado: categoria.estaBorrada
        )
    }
}

extension Api.Producto {
    init(_ producto: InventarioNucleo.Producto, fijada: CantidadFijada?) {
        self.init(
            id: producto.id.enTexto,
            categoriaId: producto.categoriaId.enTexto,
            nombre: producto.nombre,
            cantidad: fijada?.cantidad,
            cantidadFijadaEn: fijada?.en.milisegundos,
            umbralCompra: producto.umbralCompra,
            autoListaCompra: producto.autoListaCompra,
            enListaCompraManual: producto.enListaCompraManual,
            creado: producto.creado.milisegundos,
            modificado: producto.modificado.milisegundos,
            borrado: producto.estaBorrado
        )
    }
}

extension Api.Movimiento {
    init(_ movimiento: Movimiento) {
        self.init(
            id: movimiento.id.enTexto,
            productoId: movimiento.productoId.enTexto,
            cambio: movimiento.cambio,
            momento: movimiento.momento.milisegundos
        )
    }
}
