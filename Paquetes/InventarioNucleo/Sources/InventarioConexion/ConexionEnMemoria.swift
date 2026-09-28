import Foundation
import InventarioNucleo

/// Un servidor de mentira, para las pruebas del sincronizador y para
/// `-servidorFalso` en las pruebas de interfaz. Varias `ConexionEnMemoria`
/// pueden compartir uno, como varios iPhone con el mismo hogar.
///
/// Imita las reglas de `servidor/src/sincronizacion/almacen.ts` y de los
/// hogares. Si cambian allí, hay que cambiarlas aquí: las pruebas de este
/// lado no lo notarían solas.
@MainActor
public final class ServidorEnMemoria {
    private struct ProductoGuardado {
        var api: Api.Producto
        var fijada = 0
        var fijadaEn: Int64 = 0
        var revision = 0
    }

    private var usuarios: [Int: Usuario] = [:]
    private var siguienteUsuario = 1
    private var hogares: [String: (nombre: String, revision: Int)] = [:]
    /// Los hogares de cada persona, en el orden en que se unió.
    private var miembros: [Int: [String]] = [:]
    private var invitaciones: [String: String] = [:]
    private var categorias: [String: (api: Api.Categoria, hogar: String, revision: Int)] = [:]
    private var productos: [String: (guardado: ProductoGuardado, hogar: String)] = [:]
    private var movimientos: [String: Api.Movimiento] = [:]

    /// Para simular que no hay red.
    public var sinConexion = false
    /// Preferencias de notificaciones por usuario y hogar, y dispositivos registrados (token → usuario).
    public internal(set) var avisos: [Int: [String: Avisos]] = [:]
    public internal(set) var dispositivos: [String: Int] = [:]

    public init() {}

    func alta(email: String, nombre: String?, proveedor: String) -> Usuario {
        if let existente = usuarios.values.first(where: { $0.email == email && $0.proveedor == proveedor }) {
            return existente
        }
        let usuario = Usuario(id: siguienteUsuario, email: email, nombre: nombre, proveedor: proveedor)
        usuarios[usuario.id] = usuario
        siguienteUsuario += 1
        return usuario
    }

    /// Un hogar de otra persona, con algo dentro y un código fijo para unirse.
    /// Para `-servidorFalso`.
    public func sembrarHogar(nombre: String, de persona: String, codigo: String, categoria: String, producto: String) {
        let dueno = alta(email: "\(persona.lowercased())@ejemplo.com", nombre: persona, proveedor: "google")
        guard let hogar = try? crearHogar(nombre: nombre, usuario: dueno.id) else { return }
        invitaciones[codigo] = hogar.id
        let ahora = Date().milisegundos
        let categoriaId = UUID().uuidString.lowercased()
        var lote = Api.Lote()
        lote.categorias = [Api.Categoria(id: categoriaId, nombre: categoria, creado: ahora, modificado: ahora, borrado: false)]
        lote.productos = [Api.Producto(
            id: UUID().uuidString.lowercased(), categoriaId: categoriaId, nombre: producto, cantidad: 2,
            cantidadFijadaEn: ahora, umbralCompra: 1, autoListaCompra: true, enListaCompraManual: false,
            creado: ahora, modificado: ahora, borrado: false
        )]
        _ = try? enviar(lote, usuario: dueno.id, hogar: hogar.id)
    }

    /// Otra persona añade un producto a una categoría que ya existe en su
    /// hogar. Para comprobar que llega sin cerrar la app (`-cambioAjeno`).
    public func anadirProducto(de persona: String, en nombreCategoria: String, nombre: String) {
        guard let dueno = usuarios.values.first(where: { $0.nombre == persona }),
              let hogar = miembros[dueno.id]?.first,
              let categoria = categorias.values.first(where: { $0.hogar == hogar && $0.api.nombre == nombreCategoria })
        else { return }
        let ahora = Date().milisegundos
        let lote = Api.Lote(productos: [Api.Producto(
            id: UUID().uuidString.lowercased(), categoriaId: categoria.api.id, nombre: nombre, cantidad: 1,
            cantidadFijadaEn: ahora, umbralCompra: 1, autoListaCompra: true, enListaCompraManual: false,
            creado: ahora, modificado: ahora, borrado: false
        )])
        _ = try? enviar(lote, usuario: dueno.id, hogar: hogar)
    }

    // MARK: Hogar

    static let maximoHogares = 10

    private func hogar(_ id: String) -> Hogar? {
        guard let hogar = hogares[id] else { return nil }
        let gente = miembros.filter { $0.value.contains(id) }.keys.sorted().compactMap { usuarios[$0] }
        return Hogar(
            id: id, nombre: hogar.nombre,
            miembros: gente.map { Miembro(id: $0.id, nombre: $0.nombre, email: $0.email) },
            revision: hogar.revision
        )
    }

    func hogares(de usuario: Int) -> [Hogar] {
        (miembros[usuario] ?? []).compactMap(hogar)
    }

    /// Como el servidor: si no está en ese hogar, 404, igual que si no existiera.
    private func deMiembro(_ usuario: Int, _ id: String) throws(ErrorConexion) -> String {
        guard miembros[usuario]?.contains(id) == true else { throw .servidor(codigo: 404, error: "hogar no encontrado") }
        return id
    }

    func crearHogar(nombre: String, usuario: Int) throws(ErrorConexion) -> Hogar {
        guard (miembros[usuario]?.count ?? 0) < Self.maximoHogares else {
            throw .servidor(codigo: 409, error: "limite_hogares")
        }
        let id = UUID().uuidString.lowercased()
        hogares[id] = (nombre, 0)
        miembros[usuario, default: []].append(id)
        return hogar(id)!
    }

    func invitar(usuario: Int, hogar id: String) throws(ErrorConexion) -> Invitacion {
        let id = try deMiembro(usuario, id)
        let codigo = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
        invitaciones[codigo] = id
        return Invitacion(codigo: codigo, caducaEn: Date().addingTimeInterval(7 * 86_400).milisegundos)
    }

    func unirse(codigo: String, usuario: Int) throws(ErrorConexion) -> Hogar {
        guard let id = invitaciones[codigo.uppercased()] else {
            throw .servidor(codigo: 404, error: "código no válido")
        }
        // Sin gastar la invitación, como el servidor.
        if miembros[usuario]?.contains(id) == true { throw .servidor(codigo: 409, error: "ya_en_este_hogar") }
        guard (miembros[usuario]?.count ?? 0) < Self.maximoHogares else {
            throw .servidor(codigo: 409, error: "limite_hogares")
        }
        invitaciones[codigo.uppercased()] = nil
        miembros[usuario, default: []].append(id)
        return hogar(id)!
    }

    func salir(usuario: Int, hogar id: String) throws(ErrorConexion) {
        let id = try deMiembro(usuario, id)
        miembros[usuario]?.removeAll { $0 == id }
        avisos[usuario]?[id] = nil
    }

    func cambiarNombre(_ nombre: String, usuario: Int) -> Usuario {
        let viejo = usuarios[usuario]!
        let nuevo = Usuario(id: viejo.id, email: viejo.email, nombre: nombre, proveedor: viejo.proveedor)
        usuarios[usuario] = nuevo
        return nuevo
    }

    func eliminar(usuario: Int) {
        usuarios[usuario] = nil
        miembros[usuario] = nil
    }

    // MARK: Sincronización

    private func siguienteRevision(_ hogar: String) -> Int {
        hogares[hogar]!.revision += 1
        return hogares[hogar]!.revision
    }

    func enviar(_ lote: Api.Lote, usuario: Int, hogar id: String) throws(ErrorConexion) -> Api.RespuestaEnvio {
        let hogar = try deMiembro(usuario, id)
        var rechazados: [Api.Rechazado] = []
        var categoriasTocadas: [String] = []
        var productosTocados = Set<String>()

        for nueva in lote.categorias {
            if let existente = categorias[nueva.id], existente.hogar != hogar {
                rechazados.append(.init(tipo: "categoria", id: nueva.id, motivo: "no_aplicable"))
                continue
            }
            categoriasTocadas.append(nueva.id)
            // Eliminar es definitivo, como en el servidor.
            if let existente = categorias[nueva.id],
               (existente.api.borrado && nueva.restaurar != true) || nueva.modificado <= existente.api.modificado {
                continue
            }
            let guardada = Api.Categoria(
                id: nueva.id, nombre: nueva.nombre, creado: nueva.creado, modificado: nueva.modificado, borrado: nueva.borrado
            )
            categorias[nueva.id] = (guardada, hogar, siguienteRevision(hogar))
            if nueva.borrado {
                for (id, producto) in productos where producto.guardado.api.categoriaId == nueva.id && !producto.guardado.api.borrado {
                    productos[id]!.guardado.api = producto.guardado.api.cambiando(borrado: true)
                    productos[id]!.guardado.revision = siguienteRevision(hogar)
                    productosTocados.insert(id)
                }
            }
        }

        for nuevo in lote.productos {
            if let existente = productos[nuevo.id], existente.hogar != hogar {
                rechazados.append(.init(tipo: "producto", id: nuevo.id, motivo: "no_aplicable"))
                continue
            }
            guard let categoria = categorias[nuevo.categoriaId], categoria.hogar == hogar else {
                rechazados.append(.init(tipo: "producto", id: nuevo.id, motivo: "sin_categoria"))
                continue
            }
            productosTocados.insert(nuevo.id)
            let existente = productos[nuevo.id]?.guardado
            if existente?.api.borrado == true, nuevo.restaurar != true { continue }
            let gana = existente.map { nuevo.modificado > $0.api.modificado } ?? true
            let fijadaGana = nuevo.cantidadFijadaEn.map { $0 > (existente?.fijadaEn ?? -1) } ?? false
            // Lo que se guarda es la fila sin la fijada, con la cantidad que ya
            // había: la de verdad sale de `recalcular`.
            let sinFijada = nuevo.cambiando(cantidad: existente?.api.cantidad ?? 0)
            var guardado = existente ?? ProductoGuardado(api: sinFijada)
            if gana { guardado.api = sinFijada }
            if categoria.api.borrado { guardado.api = guardado.api.cambiando(borrado: true) }
            if fijadaGana, let cantidad = nuevo.cantidad, let en = nuevo.cantidadFijadaEn {
                guardado.fijada = min(max(cantidad, Limites.cantidad.lowerBound), Limites.cantidad.upperBound)
                guardado.fijadaEn = en
            }
            if gana || fijadaGana || existente == nil { guardado.revision = siguienteRevision(hogar) }
            productos[nuevo.id] = (guardado, hogar)
        }

        for movimiento in lote.movimientos {
            guard let producto = productos[movimiento.productoId], producto.hogar == hogar else {
                rechazados.append(.init(tipo: "movimiento", id: movimiento.id, motivo: "no_aplicable"))
                continue
            }
            if !producto.guardado.api.borrado, movimientos[movimiento.id] == nil {
                movimientos[movimiento.id] = movimiento
            }
            productosTocados.insert(movimiento.productoId)
        }

        for id in productosTocados { recalcular(id) }

        return Api.RespuestaEnvio(
            categorias: categoriasTocadas.map { categorias[$0]!.api },
            productos: productosTocados.sorted().map { productos[$0]!.guardado.api },
            rechazados: rechazados,
            revision: hogares[hogar]!.revision
        )
    }

    private func recalcular(_ id: String) {
        guard let (guardado, hogar) = productos[id] else { return }
        let suma = movimientos.values
            .filter { $0.productoId == id && $0.momento > guardado.fijadaEn }
            .reduce(guardado.fijada) { $0 + $1.cambio }
        let cantidad = min(max(suma, Limites.cantidad.lowerBound), Limites.cantidad.upperBound)
        if cantidad != guardado.api.cantidad {
            productos[id]!.guardado.api = guardado.api.cambiando(cantidad: cantidad)
            productos[id]!.guardado.revision = siguienteRevision(hogar)
        }
    }

    func novedades(desde: Int, usuario: Int, hogar id: String) throws(ErrorConexion) -> Api.Novedades {
        let hogar = try deMiembro(usuario, id)
        return Api.Novedades(
            categorias: categorias.values.filter { $0.hogar == hogar && $0.revision > desde }.map(\.api),
            productos: productos.values.filter { $0.hogar == hogar && $0.guardado.revision > desde }.map(\.guardado.api),
            revision: hogares[hogar]!.revision,
            masDisponible: false
        )
    }
}

/// Una conexión de un iPhone a un `ServidorEnMemoria`. Iniciar sesión con
/// Google o Apple da de alta a quien diga el código o el token, sin más.
@MainActor
public final class ConexionEnMemoria: Conexion {
    public let servidor: ServidorEnMemoria
    public private(set) var usuario: Usuario?

    public init(servidor: ServidorEnMemoria = ServidorEnMemoria()) {
        self.servidor = servidor
    }

    private func conSesion() throws(ErrorConexion) -> Int {
        if servidor.sinConexion { throw .sinConexion }
        guard let usuario else { throw .sesionCaducada }
        return usuario.id
    }

    public func restaurar() async -> Restauracion {
        usuario.map(Restauracion.conSesion) ?? .sinSesion
    }

    public func urlIniciarGoogle(estado: String) -> URL {
        URL(string: "https://servidor-falso.invalid/auth/iniciar?estado=\(estado)")!
    }

    /// El código es el correo de quien entra.
    public func entrar(conCodigoDeCanje codigo: String) async throws(ErrorConexion) -> Usuario {
        if servidor.sinConexion { throw .sinConexion }
        let nombre = String(codigo.prefix { $0 != "@" }).capitalized
        let nuevo = servidor.alta(email: codigo, nombre: nombre, proveedor: "google")
        usuario = nuevo
        return nuevo
    }

    /// Como Apple de verdad: sin nombre.
    public func entrarConApple(identityToken: String, nonce: String) async throws(ErrorConexion) -> Usuario {
        if servidor.sinConexion { throw .sinConexion }
        let nuevo = servidor.alta(email: identityToken, nombre: nil, proveedor: "apple")
        usuario = nuevo
        return nuevo
    }

    public func cerrarSesion() async { usuario = nil }

    public func hogares() async throws(ErrorConexion) -> [Hogar] { servidor.hogares(de: try conSesion()) }

    public func crearHogar(nombre: String) async throws(ErrorConexion) -> Hogar {
        try servidor.crearHogar(nombre: nombre, usuario: try conSesion())
    }

    public func unirse(codigo: String) async throws(ErrorConexion) -> Hogar {
        try servidor.unirse(codigo: codigo, usuario: try conSesion())
    }

    public func invitar(hogar: String) async throws(ErrorConexion) -> Invitacion {
        try servidor.invitar(usuario: try conSesion(), hogar: hogar)
    }

    public func salir(hogar: String) async throws(ErrorConexion) {
        try servidor.salir(usuario: try conSesion(), hogar: hogar)
    }

    public func cambiarNombre(_ nombre: String) async throws(ErrorConexion) -> Usuario {
        let nuevo = servidor.cambiarNombre(nombre, usuario: try conSesion())
        usuario = nuevo
        return nuevo
    }

    public func eliminarCuenta(codigoApple: String?) async throws(ErrorConexion) {
        let id = try conSesion()
        if usuario?.esDeApple == true, codigoApple == nil {
            throw .servidor(codigo: 400, error: "falta_codigo_apple")
        }
        servidor.eliminar(usuario: id)
        usuario = nil
    }

    public func avisos(hogar: String) async throws(ErrorConexion) -> Avisos {
        servidor.avisos[try conSesion()]?[hogar] ?? Avisos()
    }

    public func cambiarAvisos(_ avisos: Avisos, hogar: String) async throws(ErrorConexion) -> Avisos {
        servidor.avisos[try conSesion(), default: [:]][hogar] = avisos
        return avisos
    }

    public func registrarDispositivo(_ token: String, entorno: EntornoAvisos) async throws(ErrorConexion) {
        servidor.dispositivos[token] = try conSesion()
    }

    public func quitarDispositivo(_ token: String) async throws(ErrorConexion) {
        if servidor.dispositivos[token] == (try conSesion()) { servidor.dispositivos[token] = nil }
    }

    public func enviar(_ lote: Api.Lote, hogar: String) async throws(ErrorConexion) -> Api.RespuestaEnvio {
        try servidor.enviar(lote, usuario: try conSesion(), hogar: hogar)
    }

    public func novedades(desde revision: Int, hogar: String) async throws(ErrorConexion) -> Api.Novedades {
        try servidor.novedades(desde: revision, usuario: try conSesion(), hogar: hogar)
    }
}

extension Api.Producto {
    func cambiando(borrado: Bool? = nil, cantidad: Int? = nil) -> Api.Producto {
        Api.Producto(
            id: id, categoriaId: categoriaId, nombre: nombre, cantidad: cantidad ?? self.cantidad,
            cantidadFijadaEn: nil, umbralCompra: umbralCompra, autoListaCompra: autoListaCompra,
            enListaCompraManual: enListaCompraManual, creado: creado, modificado: modificado,
            borrado: borrado ?? self.borrado
        )
    }
}
