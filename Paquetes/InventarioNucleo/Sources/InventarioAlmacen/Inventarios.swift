import Foundation
import InventarioNucleo
import Observation

/// Los inventarios del iPhone, uno por hogar, y el que está abierto. Qué
/// fichero es de cada hogar lo decide `RegistroHogares`; aquí solo se abren,
/// se sueltan y se borran.
@MainActor
@Observable
public final class Inventarios {
    /// Cómo se abre, se borra y se guarda: en el disco de verdad, o en memoria
    /// para las pruebas de interfaz.
    public struct Almacenamiento {
        public var abrir: @MainActor (String) throws -> Inventario
        public var borrar: @MainActor (String) -> Void
        public var leerRegistro: @MainActor () -> RegistroHogares?
        public var guardarRegistro: @MainActor (RegistroHogares) -> Void

        public init(
            abrir: @escaping @MainActor (String) throws -> Inventario,
            borrar: @escaping @MainActor (String) -> Void,
            leerRegistro: @escaping @MainActor () -> RegistroHogares?,
            guardarRegistro: @escaping @MainActor (RegistroHogares) -> Void
        ) {
            self.abrir = abrir
            self.borrar = borrar
            self.leerRegistro = leerRegistro
            self.guardarRegistro = guardarRegistro
        }
    }

    public private(set) var registro: RegistroHogares
    /// El del hogar abierto, o el inventario sin hogar.
    public private(set) var actual: Inventario
    private let almacenamiento: Almacenamiento

    /// La primera vez, el registro sale del fichero de siempre: si estaba unido
    /// a un hogar, ese fichero es de ese hogar.
    public init(almacenamiento: Almacenamiento) throws {
        self.almacenamiento = almacenamiento
        if let guardado = almacenamiento.leerRegistro() {
            registro = guardado
            actual = try almacenamiento.abrir(guardado.ficheroActivo)
        } else {
            let original = try almacenamiento.abrir(RegistroHogares.ficheroOriginal)
            registro = .inicial(hogarDelFicheroOriginal: original.estado.hogarId)
            actual = original
            almacenamiento.guardarRegistro(registro)
        }
    }

    /// Crear un hogar, unirse o abrir uno de la cuenta que aún no estaba en el
    /// iPhone. `conservando` es qué hacer con lo que ya hay en el inventario sin
    /// hogar cuando es el primero; en los demás casos el fichero es nuevo y se
    /// llena desde el servidor.
    public func entrar(en hogar: String, conservando: Bool) throws {
        let (nuevo, _) = registro.entrar(en: hogar)
        let inventario = try almacenamiento.abrir(registro.ficheroActivo)
        if inventario.estado.hogarId != hogar {
            try inventario.unirAHogar(hogar, conservando: conservando && !nuevo)
        }
        actual = inventario
        almacenamiento.guardarRegistro(registro)
    }

    /// Cambiar a otro hogar de la cuenta. No borra nada.
    public func cambiar(a hogar: String) throws {
        // Abrir otra vez el fichero abierto daría dos conexiones a la misma base.
        guard hogar != registro.activo else { return }
        guard registro.ficheros[hogar] != nil else {
            try entrar(en: hogar, conservando: false)
            return
        }
        registro.cambiar(a: hogar)
        actual = try almacenamiento.abrir(registro.ficheroActivo)
        almacenamiento.guardarRegistro(registro)
    }

    /// Salir para siempre de un hogar. Si quedan otros, su inventario se borra
    /// del iPhone; si era el único, se queda como inventario sin hogar.
    public func salir(de hogar: String, siguiente: String?) throws {
        let eraElAbierto = registro.activo == hogar
        let borrar = registro.salir(de: hogar, siguiente: siguiente)
        if eraElAbierto { actual = try almacenamiento.abrir(registro.ficheroActivo) }
        if !registro.conHogares { try actual.separarDelHogar() }
        almacenamiento.guardarRegistro(registro)
        borrar.forEach(almacenamiento.borrar)
    }

    /// Cerrar sesión o eliminar la cuenta: se queda el del hogar abierto, sin
    /// hogar, y los demás se borran del iPhone.
    public func cerrarSesion() throws {
        let borrar = registro.cerrarSesion()
        try actual.separarDelHogar()
        almacenamiento.guardarRegistro(registro)
        borrar.forEach(almacenamiento.borrar)
    }

    /// Los hogares que ya no están en el servidor se quitan como una salida.
    public func quitarLosQueNoEstan(en hogares: [String]) throws {
        let eraElAbierto = registro.activo
        let borrar = registro.quitarLosQueNoEstan(en: hogares)
        if registro.activo != eraElAbierto { actual = try almacenamiento.abrir(registro.ficheroActivo) }
        if !registro.conHogares, actual.conHogar { try actual.separarDelHogar() }
        almacenamiento.guardarRegistro(registro)
        borrar.forEach(almacenamiento.borrar)
    }

    /// Los inventarios de los otros hogares con cambios sin enviar, para
    /// mandarlos aunque no estén abiertos.
    public func otrosConPendientes() -> [Inventario] {
        registro.ficheros
            .filter { $0.key != registro.activo }
            .compactMap { try? almacenamiento.abrir($0.value) }
            .filter { !$0.pendientes.estaVacia }
    }
}

// MARK: Dónde se guardan

extension Inventarios.Almacenamiento {
    /// En el disco del iPhone. El registro va en un JSON junto a los ficheros
    /// de SwiftData, en Application Support.
    @MainActor
    public static var enDisco: Self {
        let registro = URL.applicationSupportDirectory.appending(path: "hogares.json")
        return Self(
            abrir: { nombre in
                let inventario = Inventario(almacen: try AlmacenSwiftData.enDisco(nombre: nombre))
                try inventario.cargar()
                return inventario
            },
            borrar: { AlmacenSwiftData.borrarDelDisco(nombre: $0) },
            leerRegistro: {
                (try? Data(contentsOf: registro)).flatMap { try? JSONDecoder().decode(RegistroHogares.self, from: $0) }
            },
            guardarRegistro: { nuevo in
                try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
                try? JSONEncoder().encode(nuevo).write(to: registro, options: .atomic)
            }
        )
    }

    /// En una carpeta concreta: para probar con ficheros de verdad lo que
    /// pasa al actualizar la app, sin tocar los de Application Support.
    @MainActor
    public static func enCarpeta(_ carpeta: URL) -> Self {
        let registro = carpeta.appending(path: "hogares.json")
        let fichero = { (nombre: String) in carpeta.appending(path: "\(nombre).store") }
        return Self(
            abrir: { nombre in
                let inventario = Inventario(almacen: try AlmacenSwiftData.enFichero(fichero(nombre)))
                try inventario.cargar()
                return inventario
            },
            borrar: { nombre in
                for sufijo in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: fichero(nombre).path + sufijo))
                }
            },
            leerRegistro: {
                (try? Data(contentsOf: registro)).flatMap { try? JSONDecoder().decode(RegistroHogares.self, from: $0) }
            },
            guardarRegistro: { try? JSONEncoder().encode($0).write(to: registro, options: .atomic) }
        )
    }

    /// Para las pruebas de interfaz y los datos de ejemplo: nada toca el disco.
    /// El de siempre puede venir ya hecho (`original`).
    @MainActor
    public static func enMemoria(original: Inventario? = nil) -> Self {
        @MainActor final class Memoria {
            var inventarios: [String: Inventario] = [:]
            var registro: RegistroHogares?
        }
        let memoria = Memoria()
        if let original { memoria.inventarios[RegistroHogares.ficheroOriginal] = original }
        return Self(
            abrir: { nombre in
                if let abierto = memoria.inventarios[nombre] { return abierto }
                let nuevo = Inventario(almacen: try AlmacenSwiftData.enMemoria())
                try nuevo.cargar()
                memoria.inventarios[nombre] = nuevo
                return nuevo
            },
            borrar: { memoria.inventarios[$0] = nil },
            leerRegistro: { memoria.registro },
            guardarRegistro: { memoria.registro = $0 }
        )
    }
}
