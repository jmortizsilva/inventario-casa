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

typealias CategoriaGuardada = EsquemaV1.CategoriaGuardada
typealias ProductoGuardado = EsquemaV1.ProductoGuardado

enum PlanMigracion: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
