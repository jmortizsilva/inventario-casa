import Foundation
import InventarioNucleo

// Lo que hacen las acciones de voz, compartido por las dos formas de llegar
// a ellas: las de App Intents (app Atajos y frases de la app) y las de
// SiriKit («Añadir a Siri», `ManejadorVoz`). Los errores son `ErrorSiri`,
// con el texto que dice Siri.

/// Cambia un producto que ya existe en el hogar abierto y envía el cambio
/// sin que Siri espere a la red.
@MainActor
func cambiarProducto(
    _ id: UUID,
    nombre: String,
    arranque: Arranque,
    _ cambio: (Inventario, Producto) throws(ErrorInventario) -> Producto
) throws -> Producto {
    let inventario = try arranque.inventarioParaSiri()
    guard let producto = inventario.producto(id) else {
        // Otra persona lo eliminó mientras Siri preguntaba.
        throw ErrorSiri.noEncontrado(nombre, arranque: arranque)
    }
    let cambiado: Producto
    do {
        cambiado = try cambio(inventario, producto)
    } catch {
        throw ErrorSiri.noGuardado
    }
    arranque.enviarEnSegundoPlano()
    return cambiado
}

/// Crea un producto buscando la categoría por lo que se ha dicho, sin tildes
/// y en singular o plural. Devuelve lo que contesta Siri.
@MainActor
func crearProductoPorVoz(nombre: String, categoria: String, unidades: Int, arranque: Arranque) throws -> String {
    registroSiri.info("Crear producto: nombre «\(nombre, privacy: .public)», categoría «\(categoria, privacy: .public)», \(unidades) unidades")
    let inventario = try arranque.inventarioParaSiri()
    let encontradas = inventario.buscarCategorias(categoria)
    guard let elegida = encontradas.first else {
        throw ErrorSiri.noEncontrado(categoria, arranque: arranque)
    }
    guard encontradas.count == 1 else {
        throw ErrorSiri(mensaje: Textos.Siri.variasCategorias(encontradas.map(\.nombre)))
    }
    let creado: Producto
    do {
        creado = try inventario.crearProducto(nombre: nombre, en: elegida.id, cantidad: unidades)
    } catch .nombre(let error) {
        throw ErrorSiri(
            mensaje: Textos.Errores.nombreProducto(error, categoria: elegida.nombre)
                ?? Textos.Errores.noGuardadoMensaje
        )
    } catch {
        throw ErrorSiri.noGuardado
    }
    arranque.enviarEnSegundoPlano()
    return Textos.Siri.creado(creado.nombre, en: elegida.nombre)
}
