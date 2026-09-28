import Foundation
import Testing
import InventarioNucleo
@testable import InventarioConexion

/// Un reloj para todos los iPhone de la prueba, que avanza un segundo cada
/// vez que se consulta. Sin él todo pasa en el mismo milisegundo, y el
/// servidor resuelve los empates quedándose con lo que ya tenía: un toque
/// justo al crear el producto no contaría, y un borrado no ganaría.
@MainActor
private final class RelojCompartido {
    private var actual = Date(timeIntervalSince1970: 1_750_000_000)
    func ahora() -> Date {
        actual = actual.addingTimeInterval(1)
        return actual
    }
}

/// Un iPhone: su inventario, su conexión y su sincronizador.
@MainActor
private struct Iphone {
    let inventario: Inventario
    let conexion: ConexionEnMemoria
    let sincronizador: Sincronizador

    init(servidor: ServidorEnMemoria, reloj: RelojCompartido) {
        inventario = Inventario(almacen: AlmacenEnMemoria(), ahora: { reloj.ahora() })
        conexion = ConexionEnMemoria(servidor: servidor)
        sincronizador = Sincronizador(inventario: inventario, conexion: conexion)
    }

    func sincronizar() async throws { try await sincronizador.sincronizar() }

    func cantidad(_ nombre: String) -> Int? {
        inventario.categorias.lazy
            .flatMap { self.inventario.productos(en: $0.id) }
            .first { $0.nombre == nombre }?.cantidad
    }

    func producto(_ nombre: String) -> Producto? {
        inventario.categorias.lazy.flatMap { self.inventario.productos(en: $0.id) }.first { $0.nombre == nombre }
    }
}

/// Ana crea un hogar con lo que tenía en su iPhone y Luis se une vaciando el suyo.
@MainActor
private func hogarDeAnaYLuis() async throws
    -> (ana: Iphone, luis: Iphone, servidor: ServidorEnMemoria, reloj: RelojCompartido)
{
    let servidor = ServidorEnMemoria()
    let reloj = RelojCompartido()
    let ana = Iphone(servidor: servidor, reloj: reloj)
    let luis = Iphone(servidor: servidor, reloj: reloj)

    let despensa = try ana.inventario.crearCategoria(nombre: "Despensa")
    try ana.inventario.crearProducto(nombre: "Arroz", en: despensa.id, cantidad: 3)
    _ = try await ana.conexion.entrar(conCodigoDeCanje: "ana@ejemplo.com")
    let hogar = try await ana.conexion.crearHogar(nombre: "Casa")
    try ana.inventario.unirAHogar(hogar.id, conservando: true)
    try await ana.sincronizar()

    _ = try await luis.conexion.entrar(conCodigoDeCanje: "luis@ejemplo.com")
    let invitacion = try await ana.conexion.invitar(hogar: hogar.id)
    let mismo = try await luis.conexion.unirse(codigo: invitacion.codigo)
    try luis.inventario.unirAHogar(mismo.id, conservando: false)
    try await luis.sincronizar()
    return (ana, luis, servidor, reloj)
}

@MainActor
@Suite struct SincronizadorPruebas {
    @Test func loDeAnaLlegaALuis() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        #expect(ana.inventario.pendientes.estaVacia)
        #expect(luis.inventario.categorias.map(\.nombre) == ["Despensa"])
        #expect(luis.cantidad("Arroz") == 3)
    }

    @Test func dosPersonasRestandoALaVezRestanLasDos() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(ana.producto("Arroz"))

        try ana.inventario.ajustarCantidad(arroz.id, en: -1)
        try luis.inventario.ajustarCantidad(arroz.id, en: -1)
        try await ana.sincronizar()
        try await luis.sincronizar()
        try await ana.sincronizar()

        #expect(ana.cantidad("Arroz") == 1)
        #expect(luis.cantidad("Arroz") == 1)
    }

    @Test func sinConexionLosCambiosEsperanEnLaCola() async throws {
        let (ana, luis, servidor, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(ana.producto("Arroz"))

        servidor.sinConexion = true
        try ana.inventario.ajustarCantidad(arroz.id, en: 1)
        await #expect(throws: ErrorConexion.sinConexion) { try await ana.sincronizar() }
        #expect(ana.inventario.pendientes.cuantos == 1)
        #expect(ana.cantidad("Arroz") == 4)

        servidor.sinConexion = false
        try await ana.sincronizar()
        try await luis.sincronizar()
        #expect(ana.inventario.pendientes.estaVacia)
        #expect(luis.cantidad("Arroz") == 4)
    }

    @Test func fijarDesdeLaFichaSustituyeYLosToquesPosterioresSeSuman() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(ana.producto("Arroz"))

        try ana.inventario.editarProducto(
            arroz.id, nombre: "Arroz", cantidad: 10, umbralCompra: arroz.umbralCompra, autoListaCompra: true
        )
        try await ana.sincronizar()
        try await luis.sincronizar()
        try luis.inventario.ajustarCantidad(arroz.id, en: -1)
        try await luis.sincronizar()
        try await ana.sincronizar()

        #expect(ana.cantidad("Arroz") == 9)
        #expect(luis.cantidad("Arroz") == 9)
    }

    @Test func gananLosCambiosMasRecientes() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let despensa = try #require(ana.inventario.categorias.first)

        try ana.inventario.renombrarCategoria(despensa.id, a: "Alacena")
        try luis.inventario.renombrarCategoria(despensa.id, a: "Armario")
        try await ana.sincronizar()
        try await luis.sincronizar()
        try await ana.sincronizar()

        #expect(ana.inventario.categorias.map(\.nombre) == ["Armario"])
        #expect(luis.inventario.categorias.map(\.nombre) == ["Armario"])
    }

    @Test func borrarUnaCategoriaBorraSusProductosEnElOtroIphone() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let despensa = try #require(ana.inventario.categorias.first)

        try ana.inventario.borrarCategoria(despensa.id)
        try await ana.sincronizar()
        try await luis.sincronizar()

        #expect(luis.inventario.categorias.isEmpty)
        #expect(luis.inventario.listaCompra.isEmpty)
    }

    @Test func alUnirseConservandoSeJuntaConLoDelHogar() async throws {
        let (ana, _, servidor, reloj) = try await hogarDeAnaYLuis()
        let eva = Iphone(servidor: servidor, reloj: reloj)
        let limpieza = try eva.inventario.crearCategoria(nombre: "Limpieza")
        try eva.inventario.crearProducto(nombre: "Lejía", en: limpieza.id, cantidad: 1)

        _ = try await eva.conexion.entrar(conCodigoDeCanje: "eva@ejemplo.com")
        let deAna = try #require(ana.inventario.estado.hogarId)
        let hogar = try await eva.conexion.unirse(codigo: try await ana.conexion.invitar(hogar: deAna).codigo)
        try eva.inventario.unirAHogar(hogar.id, conservando: true)
        try await eva.sincronizar()
        try await ana.sincronizar()

        #expect(eva.inventario.categorias.map(\.nombre) == ["Despensa", "Limpieza"])
        #expect(ana.inventario.categorias.map(\.nombre) == ["Despensa", "Limpieza"])
        #expect(ana.cantidad("Lejía") == 1)
    }

    @Test func sinHogarNoHaceNada() async throws {
        let iphone = Iphone(servidor: ServidorEnMemoria(), reloj: RelojCompartido())
        try iphone.inventario.crearCategoria(nombre: "Despensa")
        try await iphone.sincronizar() // sin sesión ni hogar: no llama a nada
        #expect(iphone.inventario.pendientes.estaVacia)
    }

    @Test func muchosCambiosVanEnVariosEnvios() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(ana.producto("Arroz"))
        for _ in 0..<5 { try ana.inventario.ajustarCantidad(arroz.id, en: 1) }

        // Envío a envío hasta vaciar la cola, como haría con más de 1000.
        var vueltas = 0
        while !ana.inventario.loteParaEnviar(maximo: 2).estaVacio {
            let lote = ana.inventario.loteParaEnviar(maximo: 2)
            let respuesta = try await ana.conexion.enviar(lote, hogar: try #require(ana.inventario.estado.hogarId))
            try ana.inventario.confirmarEnvio(lote, respuesta: respuesta)
            vueltas += 1
        }
        try await luis.sincronizar()

        #expect(vueltas == 3)
        #expect(luis.cantidad("Arroz") == 8)
    }
}

/// Lo que pasó con «Legía.»: una persona la borra y la otra, sin enterarse,
/// suma unidades y cambia el nombre. Tiene que quedar borrada en los dos.
@MainActor
@Suite struct EliminarEsDefinitivoEnDosIphonePruebas {
    @Test func loBorradoNoVuelve() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(ana.producto("Arroz"))

        try luis.inventario.borrarProducto(arroz.id)
        try await luis.sincronizar()

        // Ana no se ha enterado: suma dos y cambia el nombre.
        try ana.inventario.ajustarCantidad(arroz.id, en: 1)
        try ana.inventario.ajustarCantidad(arroz.id, en: 1)
        let enAna = try #require(ana.producto("Arroz"))
        try ana.inventario.editarProducto(
            arroz.id, nombre: "Arroz largo", cantidad: enAna.cantidad, umbralCompra: enAna.umbralCompra, autoListaCompra: true
        )
        try await ana.sincronizar()
        try await luis.sincronizar()

        #expect(ana.producto("Arroz largo") == nil)
        #expect(ana.producto("Arroz") == nil)
        #expect(luis.producto("Arroz") == nil)
        #expect(luis.producto("Arroz largo") == nil)
        #expect(ana.inventario.pendientes.estaVacia)
    }

    @Test func tocarMasYMenosNoMueveLaFechaDelProducto() async throws {
        let (ana, _, _, _) = try await hogarDeAnaYLuis()
        let antes = try #require(ana.producto("Arroz"))
        try ana.inventario.ajustarCantidad(antes.id, en: 1)
        #expect(ana.producto("Arroz")?.modificado == antes.modificado)
        #expect(ana.inventario.pendientes.productos.isEmpty)
    }
}

@MainActor
@Suite struct DeshacerEnDosIphonePruebas {
    @Test func loRecuperadoVuelveEnElOtroIphone() async throws {
        let (ana, luis, _, _) = try await hogarDeAnaYLuis()
        let arroz = try #require(luis.producto("Arroz"))

        try luis.inventario.borrarProducto(arroz.id)
        try await luis.sincronizar()
        try await ana.sincronizar()
        #expect(ana.producto("Arroz") == nil)

        try luis.inventario.deshacerEliminacion()
        try await luis.sincronizar()
        try await ana.sincronizar()

        #expect(luis.producto("Arroz") != nil)
        #expect(ana.cantidad("Arroz") == 3)
    }
}

/// Una misma persona en dos hogares: cada inventario va por separado.
@MainActor
@Suite struct VariosHogaresPruebas {
    @Test func loDeUnHogarNoLlegaAlOtro() async throws {
        let servidor = ServidorEnMemoria()
        let reloj = RelojCompartido()
        let enCasa = Iphone(servidor: servidor, reloj: reloj)
        _ = try await enCasa.conexion.entrar(conCodigoDeCanje: "ana@ejemplo.com")
        let casa = try await enCasa.conexion.crearHogar(nombre: "Casa")
        let playa = try await enCasa.conexion.crearHogar(nombre: "Playa")
        try enCasa.inventario.unirAHogar(casa.id, conservando: false)
        try enCasa.inventario.crearCategoria(nombre: "Despensa")
        try await enCasa.sincronizar()

        // La misma cuenta, con el inventario de la playa.
        let enPlaya = Iphone(servidor: servidor, reloj: reloj)
        _ = try await enPlaya.conexion.entrar(conCodigoDeCanje: "ana@ejemplo.com")
        try enPlaya.inventario.unirAHogar(playa.id, conservando: false)
        try await enPlaya.sincronizar()

        #expect(enPlaya.inventario.categorias.isEmpty)
        #expect(try await enCasa.conexion.hogares().map(\.nombre) == ["Casa", "Playa"])
    }

    @Test func unirseAlQueYaEsTuyoNoGastaLaInvitacion() async throws {
        let servidor = ServidorEnMemoria()
        let ana = ConexionEnMemoria(servidor: servidor)
        _ = try await ana.entrar(conCodigoDeCanje: "ana@ejemplo.com")
        let casa = try await ana.crearHogar(nombre: "Casa")
        let invitacion = try await ana.invitar(hogar: casa.id)

        await #expect(throws: ErrorConexion.servidor(codigo: 409, error: "ya_en_este_hogar")) {
            _ = try await ana.unirse(codigo: invitacion.codigo)
        }
        let luis = ConexionEnMemoria(servidor: servidor)
        _ = try await luis.entrar(conCodigoDeCanje: "luis@ejemplo.com")
        #expect(try await luis.unirse(codigo: invitacion.codigo).id == casa.id)
    }

    @Test func enUnHogarAjenoNoEntra() async throws {
        let servidor = ServidorEnMemoria()
        let ana = ConexionEnMemoria(servidor: servidor)
        _ = try await ana.entrar(conCodigoDeCanje: "ana@ejemplo.com")
        let casa = try await ana.crearHogar(nombre: "Casa")
        let luis = ConexionEnMemoria(servidor: servidor)
        _ = try await luis.entrar(conCodigoDeCanje: "luis@ejemplo.com")

        await #expect(throws: ErrorConexion.servidor(codigo: 404, error: "hogar no encontrado")) {
            _ = try await luis.novedades(desde: 0, hogar: casa.id)
        }
    }
}
