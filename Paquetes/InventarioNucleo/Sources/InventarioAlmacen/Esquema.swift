import Foundation
import SwiftData

/// Esquema versionado desde el principio: cuando cambie el modelo, se añade
/// una versión nueva y un plan de migración en lugar de tocar esta.
enum EsquemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [CategoriaGuardada.self, ProductoGuardado.self] }

    @Model
    final class CategoriaGuardada {
        @Attribute(.unique) var id: UUID
        var nombre: String
        var creado: Date
        var modificado: Date
        var borrado: Date?

        init(id: UUID, nombre: String, creado: Date, modificado: Date, borrado: Date?) {
            self.id = id
            self.nombre = nombre
            self.creado = creado
            self.modificado = modificado
            self.borrado = borrado
        }
    }

    @Model
    final class ProductoGuardado {
        @Attribute(.unique) var id: UUID
        var categoriaId: UUID
        var nombre: String
        var cantidad: Int
        var umbralCompra: Int
        var autoListaCompra: Bool
        var enListaCompraManual: Bool
        var creado: Date
        var modificado: Date
        var borrado: Date?

        init(
            id: UUID, categoriaId: UUID, nombre: String, cantidad: Int, umbralCompra: Int,
            autoListaCompra: Bool, enListaCompraManual: Bool, creado: Date, modificado: Date, borrado: Date?
        ) {
            self.id = id
            self.categoriaId = categoriaId
            self.nombre = nombre
            self.cantidad = cantidad
            self.umbralCompra = umbralCompra
            self.autoListaCompra = autoListaCompra
            self.enListaCompraManual = enListaCompraManual
            self.creado = creado
            self.modificado = modificado
            self.borrado = borrado
        }
    }
}

/// La sincronización: a qué hogar está unido el iPhone, hasta qué revisión
/// ha bajado y qué falta por enviar. Categorías y productos no cambian, así
/// que se reutilizan los de la V1.
enum EsquemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [EsquemaV1.CategoriaGuardada.self, EsquemaV1.ProductoGuardado.self, SincronizacionGuardada.self]
    }

    /// Una sola fila. La cola va entera en JSON: se reescribe con cada cambio,
    /// pero así cambio y cola se guardan en el mismo `save`. En tablas aparte,
    /// una por tipo de pendiente, daría lo mismo con cuatro modelos más.
    @Model
    final class SincronizacionGuardada {
        var hogarId: String?
        var revision: Int
        var pendientes: Data

        init(hogarId: String?, revision: Int, pendientes: Data) {
            self.hogarId = hogarId
            self.revision = revision
            self.pendientes = pendientes
        }
    }
}

/// En qué se cuenta cada producto (`Unidad`). Lo demás no cambia.
enum EsquemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [EsquemaV1.CategoriaGuardada.self, ProductoGuardado.self, EsquemaV2.SincronizacionGuardada.self]
    }

    @Model
    final class ProductoGuardado {
        @Attribute(.unique) var id: UUID
        var categoriaId: UUID
        var nombre: String
        /// El valor en bruto de `Unidad`. Con valor por defecto para que los
        /// productos que ya había se migren solos, como unidades.
        var unidad: String = "unidad"
        var cantidad: Int
        var umbralCompra: Int
        var autoListaCompra: Bool
        var enListaCompraManual: Bool
        var creado: Date
        var modificado: Date
        var borrado: Date?

        init(
            id: UUID, categoriaId: UUID, nombre: String, unidad: String, cantidad: Int, umbralCompra: Int,
            autoListaCompra: Bool, enListaCompraManual: Bool, creado: Date, modificado: Date, borrado: Date?
        ) {
            self.id = id
            self.categoriaId = categoriaId
            self.nombre = nombre
            self.unidad = unidad
            self.cantidad = cantidad
            self.umbralCompra = umbralCompra
            self.autoListaCompra = autoListaCompra
            self.enListaCompraManual = enListaCompraManual
            self.creado = creado
            self.modificado = modificado
            self.borrado = borrado
        }
    }
}

typealias CategoriaGuardada = EsquemaV1.CategoriaGuardada
typealias ProductoGuardado = EsquemaV3.ProductoGuardado
typealias SincronizacionGuardada = EsquemaV2.SincronizacionGuardada

enum PlanMigracion: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self, EsquemaV2.self, EsquemaV3.self] }
    /// Se añade un modelo y después una columna con valor por defecto: SwiftData
    /// migra las dos sin código.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: EsquemaV1.self, toVersion: EsquemaV2.self),
            .lightweight(fromVersion: EsquemaV2.self, toVersion: EsquemaV3.self),
        ]
    }
}
