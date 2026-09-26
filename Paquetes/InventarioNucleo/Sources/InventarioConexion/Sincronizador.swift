import Foundation
import InventarioNucleo

/// Un ciclo de sincronización: primero se envía la cola, después se baja lo
/// que haya cambiado. Qué se envía y cómo se mezcla lo decide el núcleo; aquí
/// solo se encadenan inventario y conexión.
@MainActor
public final class Sincronizador {
    private let inventario: Inventario
    private let conexion: Conexion

    public init(inventario: Inventario, conexion: Conexion) {
        self.inventario = inventario
        self.conexion = conexion
    }

    /// Sin hogar no hace nada. Los errores de red se propagan: quien llama
    /// decide si lo dice o lo reintenta más tarde. Lo que no se pudo enviar
    /// sigue en la cola.
    public func sincronizar() async throws {
        guard inventario.conHogar else { return }
        try await enviar()
        try await bajar()
    }

    private func enviar() async throws {
        // Cada vuelta tiene que vaciar algo de la cola. Si no, algo va mal y
        // repetir el mismo envío no lo va a arreglar.
        var quedaban = Int.max
        while inventario.pendientes.cuantos > 0, inventario.pendientes.cuantos < quedaban {
            quedaban = inventario.pendientes.cuantos
            let lote = inventario.loteParaEnviar()
            guard !lote.estaVacio else { return }
            let respuesta = try await conexion.enviar(lote)
            try inventario.confirmarEnvio(lote, respuesta: respuesta)
        }
    }

    private func bajar() async throws {
        while true {
            let novedades = try await conexion.novedades(desde: inventario.estado.revision)
            try inventario.aplicarNovedades(novedades)
            guard novedades.masDisponible else { return }
        }
    }
}
