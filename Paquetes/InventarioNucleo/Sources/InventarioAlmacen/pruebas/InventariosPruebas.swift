import Foundation
import Testing
import InventarioNucleo
@testable import InventarioAlmacen

/// Los inventarios de varios hogares con ficheros de verdad, en una carpeta
/// temporal. Sobre todo, lo que pasa en el iPhone de quien ya usa la app al
/// actualizar: su inventario no se puede perder.
@MainActor
@Suite struct InventariosPruebas {
    let carpeta: URL

    init() throws {
        carpeta = FileManager.default.temporaryDirectory.appending(path: "inventarios-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
    }

    private func fichero(_ nombre: String) -> URL { carpeta.appending(path: "\(nombre).store") }

    /// El fichero de siempre, como lo dejó la versión anterior, y cerrado.
    private func versionAnterior(hogar: String?, categoria: String) throws {
        let inventario = Inventario(almacen: try AlmacenSwiftData.enFichero(fichero(RegistroHogares.ficheroOriginal)))
        try inventario.cargar()
        if let hogar { try inventario.unirAHogar(hogar, conservando: true) }
        try inventario.crearCategoria(nombre: categoria)
    }

    @Test func alActualizarElInventarioSigueSiendoDeSuHogar() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")

        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))

        #expect(inventarios.registro.activo == "casa")
        #expect(inventarios.actual.categorias.map(\.nombre) == ["Despensa"])
        #expect(inventarios.actual.estado.hogarId == "casa")
        // Lo que no se había enviado sigue en la cola.
        #expect(!inventarios.actual.pendientes.estaVacia)
    }

    @Test func alActualizarSinHogarSigueSinHogar() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: nil, categoria: "Despensa")

        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))

        #expect(inventarios.registro.activo == nil)
        #expect(inventarios.actual.categorias.map(\.nombre) == ["Despensa"])
    }

    @Test func otroHogarTieneSuFicheroYCambiarNoBorraNada() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")
        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))

        try inventarios.entrar(en: "playa", conservando: true)
        #expect(inventarios.actual.categorias.isEmpty)
        #expect(inventarios.actual.estado.hogarId == "playa")
        try inventarios.actual.crearCategoria(nombre: "Toallas")

        try inventarios.cambiar(a: "casa")
        #expect(inventarios.actual.categorias.map(\.nombre) == ["Despensa"])
        try inventarios.cambiar(a: "playa")
        #expect(inventarios.actual.categorias.map(\.nombre) == ["Toallas"])
    }

    @Test func alReabrirSigueEnElMismoHogar() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")
        do {
            let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))
            try inventarios.entrar(en: "playa", conservando: false)
        }

        let otraVez = try Inventarios(almacenamiento: .enCarpeta(carpeta))

        #expect(otraVez.registro.activo == "playa")
        #expect(otraVez.actual.estado.hogarId == "playa")
    }

    @Test func salirDeUnoTeniendoOtrosBorraSuFichero() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")
        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))
        try inventarios.entrar(en: "playa", conservando: false)
        let deLaPlaya = fichero(RegistroHogares.fichero(de: "playa"))
        #expect(FileManager.default.fileExists(atPath: deLaPlaya.path))

        try inventarios.salir(de: "playa", siguiente: "casa")

        #expect(!FileManager.default.fileExists(atPath: deLaPlaya.path))
        #expect(inventarios.actual.categorias.map(\.nombre) == ["Despensa"])
    }

    @Test func salirDelUnicoDejaElInventarioSinHogar() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")
        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))

        try inventarios.salir(de: "casa", siguiente: nil)

        #expect(inventarios.actual.categorias.map(\.nombre) == ["Despensa"])
        #expect(!inventarios.actual.conHogar)
        #expect(FileManager.default.fileExists(atPath: fichero(RegistroHogares.ficheroOriginal).path))
    }

    @Test func cerrarSesionDejaElAbiertoYBorraLosDemas() throws {
        defer { try? FileManager.default.removeItem(at: carpeta) }
        try versionAnterior(hogar: "casa", categoria: "Despensa")
        let inventarios = try Inventarios(almacenamiento: .enCarpeta(carpeta))
        try inventarios.entrar(en: "playa", conservando: false)
        try inventarios.actual.crearCategoria(nombre: "Toallas")

        try inventarios.cerrarSesion()

        #expect(inventarios.actual.categorias.map(\.nombre) == ["Toallas"])
        #expect(!inventarios.actual.conHogar)
        #expect(!FileManager.default.fileExists(atPath: fichero(RegistroHogares.ficheroOriginal).path))
    }
}
