import Testing
@testable import InventarioNucleo

@Suite struct NombresPruebas {
    @Test func limpiaEspacios() {
        #expect(Nombres.limpiar("  Leche   entera \n") == "Leche entera")
    }

    @Test func vacioOSoloEspacios() {
        #expect(Nombres.validar("   ", existentes: []) == .failure(.vacio))
    }

    @Test func largoMaximo() {
        let justo = String(repeating: "a", count: Limites.largoMaximoNombre)
        #expect(Nombres.validar(justo, existentes: []) == .success(justo))
        #expect(
            Nombres.validar(justo + "a", existentes: [])
                == .failure(.demasiadoLargo(maximo: Limites.largoMaximoNombre))
        )
    }

    @Test func elLargoCuentaLetrasNoBytes() {
        let conTildes = String(repeating: "ñ", count: Limites.largoMaximoNombre)
        #expect(Nombres.validar(conTildes, existentes: []) == .success(conTildes))
    }

    @Test(arguments: [
        ("leche", "Leche"),
        ("azucar", "Azúcar"),
        ("Leche  entera", " leche entera"),
        ("PIÑA", "piña"),
    ])
    func repetidosSinMayusculasNiTildes(nuevo: String, existente: String) {
        #expect(Nombres.validar(nuevo, existentes: [existente]) == .failure(.repetido))
    }

    @Test func distintosNoSonRepetidos() {
        #expect(Nombres.validar("Leche entera", existentes: ["Leche", "Leche desnatada"]) == .success("Leche entera"))
    }

    @Test func laEnieNoSeConfundeConLaEne() {
        #expect(Nombres.clave("Año") != Nombres.clave("ano"))
        #expect(Nombres.validar("Piña", existentes: ["Pina"]) == .success("Piña"))
        #expect(Nombres.validar("piña", existentes: ["PIÑA"]) == .failure(.repetido))
    }

    @Test func laEnieDescompuestaEsLaMisma() {
        // «n» seguida de la tilde combinable, como puede llegar desde el teclado o de otro sistema.
        #expect(Nombres.clave("Pin\u{0303}a") == Nombres.clave("Piña"))
    }

    @Test func ordenAlfabeticoEspanol() {
        let ordenadas = ["oca", "ñame", "Nata", "Zumo", "azúcar", "Pilas 10", "Pilas 2"]
            .sorted(by: Nombres.vaAntes)
        #expect(ordenadas == ["azúcar", "Nata", "ñame", "oca", "Pilas 2", "Pilas 10", "Zumo"])
    }
}
