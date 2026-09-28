import Foundation
import Testing
@testable import InventarioNucleo

@Suite struct RegistroHogaresPruebas {
    let original = RegistroHogares.ficheroOriginal

    @Test func loQueYaHabiaSeQuedaEnSuFichero() {
        let unido = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        #expect(unido.ficheros == ["casa": original])
        #expect(unido.activo == "casa")
        #expect(unido.ficheroActivo == original)

        let solo = RegistroHogares.inicial(hogarDelFicheroOriginal: nil)
        #expect(solo.ficheros.isEmpty)
        #expect(solo.sinHogar == original)
        #expect(solo.ficheroActivo == original)
    }

    @Test func elPrimerHogarSeQuedaConElInventarioSinHogar() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: nil)
        let (nuevo, borrar) = registro.entrar(en: "casa")
        #expect(!nuevo)
        #expect(borrar.isEmpty)
        #expect(registro.ficheros == ["casa": original])
        #expect(registro.sinHogar == nil)
    }

    @Test func losDemasHogaresTienenSuFicheroNuevo() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        let (nuevo, _) = registro.entrar(en: "playa")
        #expect(nuevo)
        #expect(registro.activo == "playa")
        #expect(registro.ficheroActivo == RegistroHogares.fichero(de: "playa"))
        #expect(registro.ficheros["casa"] == original)
    }

    @Test func cambiarNoBorraNada() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        registro.entrar(en: "playa")
        registro.cambiar(a: "casa")
        #expect(registro.ficheroActivo == original)
        #expect(registro.ficheros.count == 2)
        registro.cambiar(a: "no-existe")
        #expect(registro.activo == "casa")
    }

    @Test func salirTeniendoOtrosBorraSuFicheroYAbreOtro() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        registro.entrar(en: "playa")
        let borrar = registro.salir(de: "playa", siguiente: "casa")
        #expect(borrar == [RegistroHogares.fichero(de: "playa")])
        #expect(registro.activo == "casa")
        #expect(registro.ficheros == ["casa": original])
    }

    @Test func salirDelUnicoDejaSuInventarioSinHogar() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        let borrar = registro.salir(de: "casa")
        #expect(borrar.isEmpty)
        #expect(registro.activo == nil)
        #expect(registro.sinHogar == original)
        #expect(!registro.conHogares)
    }

    @Test func cerrarSesionDejaElAbiertoYBorraLosDemas() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        registro.entrar(en: "playa")
        registro.entrar(en: "pueblo")
        registro.cambiar(a: "playa")

        let borrar = registro.cerrarSesion()

        #expect(Set(borrar) == [original, RegistroHogares.fichero(de: "pueblo")])
        #expect(registro.sinHogar == RegistroHogares.fichero(de: "playa"))
        #expect(registro.ficheroActivo == RegistroHogares.fichero(de: "playa"))
        #expect(!registro.conHogares)
    }

    @Test func losQueYaNoEstanEnElServidorSeQuitan() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        registro.entrar(en: "playa")

        let borrar = registro.quitarLosQueNoEstan(en: ["casa"])

        #expect(borrar == [RegistroHogares.fichero(de: "playa")])
        #expect(registro.activo == "casa")
    }

    @Test func siYaNoEstaEnNingunoSeQuedaConElAbierto() {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        let borrar = registro.quitarLosQueNoEstan(en: [])
        #expect(borrar.isEmpty)
        #expect(registro.sinHogar == original)
        #expect(registro.activo == nil)
    }

    @Test func seGuardaYSeLee() throws {
        var registro = RegistroHogares.inicial(hogarDelFicheroOriginal: "casa")
        registro.entrar(en: "playa")
        let leido = try JSONDecoder().decode(RegistroHogares.self, from: JSONEncoder().encode(registro))
        #expect(leido == registro)
    }
}
