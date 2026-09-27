import Foundation
import Testing
@testable import InventarioNucleo

// MARK: Casos compartidos

struct CasoCantidadMovil: Decodable, CustomTestStringConvertible, Sendable {
    struct Fijada: Decodable, Sendable { let cantidad: Int; let en: Int64 }
    struct Mov: Decodable, Sendable { let cambio: Int; let momento: Int64 }
    let caso: String
    let servidor: Int
    let fijada: Fijada?
    let movimientos: [Mov]
    let cantidad: Int

    var testDescription: String { caso }
}

/// Los casos viven en `pruebas-compartidas/`, fuera del paquete, porque los
/// usan también el servidor y la app de Android. Se leen por ruta: el
/// simulador ve el disco del Mac.
private func cargarCasosCantidadMovil() throws -> [CasoCantidadMovil] {
    struct Fichero: Decodable { let casos: [CasoCantidadMovil] }
    return try JSONDecoder().decode(Fichero.self, from: Data(contentsOf: rutaCompartida("cantidad-en-el-movil.json"))).casos
}

@Suite struct CantidadVisiblePruebas {
    @Test(arguments: try cargarCasosCantidadMovil())
    func casosCompartidos(_ caso: CasoCantidadMovil) {
        let productoId = UUID()
        let cantidad = Sincronizacion.cantidadVisible(
            servidor: caso.servidor,
            fijada: caso.fijada.map { CantidadFijada(cantidad: $0.cantidad, en: Date(milisegundos: $0.en)) },
            movimientos: caso.movimientos.map {
                Movimiento(productoId: productoId, cambio: $0.cambio, momento: Date(milisegundos: $0.momento))
            }
        )
        #expect(cantidad == caso.cantidad)
    }
}

// MARK: Formato del contrato

@Suite struct ApiPruebas {
    @Test func leeLaRespuestaDelServidor() throws {
        let json = """
        {
          "categorias": [ { "id": "0d9c1c1e-6f59-4b6a-9d5e-1f2a3b4c5d6e", "nombre": "Despensa",
                            "creado": 1735000000000, "modificado": 1735600000000, "borrado": false } ],
          "productos": [ { "id": "a1b2c3d4-0000-4000-8000-000000000001", "categoriaId": "0d9c1c1e-6f59-4b6a-9d5e-1f2a3b4c5d6e",
                           "nombre": "Arroz", "cantidad": 3, "umbralCompra": 2, "autoListaCompra": true,
                           "enListaCompraManual": false, "creado": 1735000000000, "modificado": 1735600000000,
                           "borrado": false } ],
          "rechazados": [ { "tipo": "producto", "id": "x", "motivo": "no_valido" } ],
          "revision": 131
        }
        """
        let respuesta = try JSONDecoder().decode(Api.RespuestaEnvio.self, from: Data(json.utf8))
        #expect(respuesta.revision == 131)
        #expect(respuesta.productos.first?.cantidad == 3)
        #expect(respuesta.productos.first?.cantidadFijadaEn == nil)
        #expect(respuesta.rechazados.first?.motivo == "no_valido")
    }

    @Test func sinFijadaNoMandaCantidad() throws {
        let p = producto("Arroz", cantidad: 7)
        let datos = try JSONEncoder().encode(Api.Producto(p, fijada: nil))
        let campos = try #require(try JSONSerialization.jsonObject(with: datos) as? [String: Any])
        #expect(campos["cantidad"] == nil)
        #expect(campos["cantidadFijadaEn"] == nil)
        #expect(campos["id"] as? String == p.id.uuidString.lowercased())
        #expect(campos["creado"] as? Int64 == instante.milisegundos)
    }

    @Test func conFijadaMandaCantidadYHora() {
        let p = producto("Arroz", cantidad: 7)
        let api = Api.Producto(p, fijada: CantidadFijada(cantidad: 7, en: despues))
        #expect(api.cantidad == 7)
        #expect(api.cantidadFijadaEn == despues.milisegundos)
    }

    @Test func unaFechaDelServidorVuelveIgual() {
        for ms: Int64 in [0, 1, 1999, 1_735_600_000_123, 1_790_414_493_087] {
            #expect(Date(milisegundos: ms).milisegundos == ms)
        }
    }
}

// MARK: Enviar

private func indice<T: Identifiable>(_ elementos: [T]) -> [T.ID: T] {
    Dictionary(uniqueKeysWithValues: elementos.map { ($0.id, $0) })
}

@Suite struct LotePruebas {
    let despensa = Categoria(nombre: "Despensa", creado: instante)

    @Test func categoriasDespuesProductosDespuesMovimientos() {
        let arroz = producto("Arroz", categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(Movimiento(productoId: arroz.id, cambio: 1, momento: despues))
        cola.anotar(producto: arroz.id)
        cola.anotar(categoria: despensa.id)

        let lote = Sincronizacion.lote(cola, categorias: indice([despensa]), productos: indice([arroz]))

        #expect(lote.categorias.map(\.nombre) == ["Despensa"])
        #expect(lote.productos.map(\.nombre) == ["Arroz"])
        #expect(lote.movimientos.map(\.cambio) == [1])
    }

    @Test func loQueNoCabeQuedaDetrasDeLoQueNecesita() {
        let arroz = producto("Arroz", categoriaId: despensa.id)
        let pan = producto("Pan", categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(categoria: despensa.id)
        cola.anotar(producto: arroz.id)
        cola.anotar(producto: pan.id)
        cola.anotar(Movimiento(productoId: arroz.id, cambio: 1, momento: despues))

        let lote = Sincronizacion.lote(
            cola, categorias: indice([despensa]), productos: indice([arroz, pan]), maximo: 2
        )

        // Ningún movimiento hasta que hayan entrado todos los productos.
        #expect(lote.cuantos == 2)
        #expect(lote.categorias.count == 1)
        #expect(lote.productos.count == 1)
        #expect(lote.movimientos.isEmpty)
    }

    @Test func productoConFijadaLaLleva() {
        let arroz = producto("Arroz", cantidad: 4, categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(fijada: CantidadFijada(cantidad: 4, en: despues), producto: arroz.id)

        let lote = Sincronizacion.lote(cola, categorias: [:], productos: indice([arroz]))

        #expect(lote.productos.first?.cantidad == 4)
        #expect(lote.productos.first?.cantidadFijadaEn == despues.milisegundos)
    }

    @Test func movimientosEnOrdenDeMomento() {
        let arroz = producto("Arroz")
        var cola = Pendientes()
        cola.anotar(Movimiento(productoId: arroz.id, cambio: -1, momento: despues))
        cola.anotar(Movimiento(productoId: arroz.id, cambio: 1, momento: instante))

        let lote = Sincronizacion.lote(cola, categorias: [:], productos: [:])

        #expect(lote.movimientos.map(\.cambio) == [1, -1])
    }
}

@Suite struct ConfirmarPruebas {
    let despensa = Categoria(nombre: "Despensa", creado: instante)

    @Test func saleTodoLoEnviadoSinCambios() {
        let arroz = producto("Arroz", categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(categoria: despensa.id)
        cola.anotar(fijada: CantidadFijada(cantidad: 5, en: instante), producto: arroz.id)
        cola.anotar(Movimiento(productoId: arroz.id, cambio: 1, momento: despues))
        let categorias = indice([despensa])
        let productos = indice([arroz])
        let enviado = Sincronizacion.lote(cola, categorias: categorias, productos: productos)

        let despuesDeEnviar = Sincronizacion.confirmar(
            cola, enviado: enviado, categorias: categorias, productos: productos
        )

        #expect(despuesDeEnviar.estaVacia)
        #expect(despuesDeEnviar.fijadas.isEmpty)
    }

    @Test func loQueCambioDuranteElEnvioSigueEnLaCola() {
        var cola = Pendientes()
        cola.anotar(categoria: despensa.id)
        let enviado = Sincronizacion.lote(cola, categorias: indice([despensa]), productos: [:])

        var renombrada = despensa
        renombrada.nombre = "Alacena"
        renombrada.modificado = despues

        let despuesDeEnviar = Sincronizacion.confirmar(
            cola, enviado: enviado, categorias: indice([renombrada]), productos: [:]
        )

        #expect(despuesDeEnviar.categorias == [despensa.id])
    }

    @Test func unaFijadaNuevaDuranteElEnvioSigueEnLaCola() {
        let arroz = producto("Arroz", cantidad: 5)
        var cola = Pendientes()
        cola.anotar(fijada: CantidadFijada(cantidad: 5, en: instante), producto: arroz.id)
        let enviado = Sincronizacion.lote(cola, categorias: [:], productos: indice([arroz]))
        cola.anotar(fijada: CantidadFijada(cantidad: 8, en: despues), producto: arroz.id)

        let despuesDeEnviar = Sincronizacion.confirmar(
            cola, enviado: enviado, categorias: [:], productos: indice([arroz])
        )

        #expect(despuesDeEnviar.productos == [arroz.id])
        #expect(despuesDeEnviar.fijadas[arroz.id]?.cantidad == 8)
    }

    @Test func movimientoNuevoDuranteElEnvioSigue() {
        let arroz = producto("Arroz")
        var cola = Pendientes()
        cola.anotar(Movimiento(productoId: arroz.id, cambio: 1, momento: instante))
        let enviado = Sincronizacion.lote(cola, categorias: [:], productos: [:])
        let nuevo = Movimiento(productoId: arroz.id, cambio: 1, momento: despues)
        cola.anotar(nuevo)

        let despuesDeEnviar = Sincronizacion.confirmar(cola, enviado: enviado, categorias: [:], productos: [:])

        #expect(Array(despuesDeEnviar.movimientos.keys) == [nuevo.id])
    }
}

// MARK: Recibir

@Suite struct FusionarPruebas {
    let despensa = Categoria(nombre: "Despensa", creado: instante)

    private func deServidor(_ p: Producto, cantidad: Int, nombre: String? = nil, borrado: Bool = false) -> Api.Producto {
        Api.Producto(
            id: p.id.enTexto, categoriaId: p.categoriaId.enTexto, nombre: nombre ?? p.nombre,
            cantidad: cantidad, cantidadFijadaEn: nil, umbralCompra: p.umbralCompra,
            autoListaCompra: p.autoListaCompra, enListaCompraManual: p.enListaCompraManual,
            creado: p.creado.milisegundos, modificado: despues.milisegundos, borrado: borrado
        )
    }

    @Test func loNuevoDelServidorEntra() {
        let arroz = producto("Arroz", cantidad: 2, categoriaId: despensa.id)

        let (categorias, productos) = Sincronizacion.fusionar(
            categorias: [Api.Categoria(despensa)],
            productos: [deServidor(arroz, cantidad: 3)],
            en: ([:], [:]),
            pendientes: Pendientes()
        )

        #expect(categorias.map(\.id) == [despensa.id])
        #expect(productos.first?.cantidad == 3)
        #expect(productos.first?.modificado == despues)
    }

    @Test func loQueSigueEnLaColaNoSePisa() {
        var local = producto("Arroz", cantidad: 2, categoriaId: despensa.id)
        local.nombre = "Arroz integral"
        var cola = Pendientes()
        cola.anotar(producto: local.id)

        let (_, productos) = Sincronizacion.fusionar(
            categorias: [],
            productos: [deServidor(local, cantidad: 2, nombre: "Arroz")],
            en: ([:], indice([local])),
            pendientes: cola
        )

        // Nada cambia: el nombre local se queda y las unidades coinciden.
        #expect(productos.isEmpty)
    }

    @Test func unToqueSinEnviarNoDesapareceConUnaBajada() {
        let local = producto("Arroz", cantidad: 3, categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(Movimiento(productoId: local.id, cambio: 1, momento: despues))

        // Otra persona restó uno: el servidor dice 1. Aquí se había sumado uno sin enviar.
        let (_, productos) = Sincronizacion.fusionar(
            categorias: [],
            productos: [deServidor(local, cantidad: 1)],
            en: ([:], indice([local])),
            pendientes: cola
        )

        #expect(productos.first?.cantidad == 2)
    }

    @Test func lasUnidadesDelServidorNoMuevenLaFechaDeLoPendiente() {
        let local = producto("Arroz", cantidad: 3, categoriaId: despensa.id)
        var cola = Pendientes()
        cola.anotar(producto: local.id)

        let (_, productos) = Sincronizacion.fusionar(
            categorias: [],
            productos: [deServidor(local, cantidad: 7)],
            en: ([:], indice([local])),
            pendientes: cola
        )

        #expect(productos.first?.cantidad == 7)
        #expect(productos.first?.modificado == local.modificado)
    }

    @Test func borradoEnElServidorSeBorraAqui() {
        let local = producto("Arroz", categoriaId: despensa.id)

        let (_, productos) = Sincronizacion.fusionar(
            categorias: [],
            productos: [deServidor(local, cantidad: 0, borrado: true)],
            en: ([:], indice([local])),
            pendientes: Pendientes()
        )

        #expect(productos.first?.estaBorrado == true)
    }

    @Test func loIgualNoSeDevuelve() {
        let (categorias, _) = Sincronizacion.fusionar(
            categorias: [Api.Categoria(despensa)],
            productos: [],
            en: (indice([despensa]), [:]),
            pendientes: Pendientes()
        )
        #expect(categorias.isEmpty)
    }

    @Test func identificadoresQueNoSonUUIDSeIgnoran() {
        let rara = Api.Categoria(id: "no-es-uuid", nombre: "X", creado: 0, modificado: 0, borrado: false)
        let (categorias, _) = Sincronizacion.fusionar(
            categorias: [rara], productos: [], en: ([:], [:]), pendientes: Pendientes()
        )
        #expect(categorias.isEmpty)
    }
}

@Suite struct EliminarEsDefinitivoPruebas {
    @Test func unBorradoDelServidorGanaAunqueHayaCambiosEnLaCola() {
        let despensa = Categoria(nombre: "Despensa", creado: instante)
        var local = producto("Legía", cantidad: 2, categoriaId: despensa.id)
        local.nombre = "Legía."
        var cola = Pendientes()
        cola.anotar(producto: local.id)
        cola.anotar(categoria: despensa.id)
        let borrado = Api.Producto(local, fijada: nil)
        let productoBorrado = Api.Producto(
            id: borrado.id, categoriaId: borrado.categoriaId, nombre: "Legía", cantidad: 2, cantidadFijadaEn: nil,
            umbralCompra: borrado.umbralCompra, autoListaCompra: true, enListaCompraManual: false,
            creado: borrado.creado, modificado: despues.milisegundos, borrado: true
        )
        let categoriaBorrada = Api.Categoria(
            id: despensa.id.uuidString.lowercased(), nombre: "Despensa", creado: instante.milisegundos,
            modificado: despues.milisegundos, borrado: true
        )

        let (categorias, productos) = Sincronizacion.fusionar(
            categorias: [categoriaBorrada],
            productos: [productoBorrado],
            en: ([despensa.id: despensa], [local.id: local]),
            pendientes: cola
        )

        #expect(categorias.first?.estaBorrada == true)
        #expect(productos.first?.estaBorrado == true)
    }
}
