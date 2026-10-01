import Testing
@testable import InventarioNucleo

@Suite struct PeticionVozPruebas {
    @Test(arguments: [
        ("5 unidades de leche", 5, "leche"),
        ("2 latas de atún", 2, "atún"),
        ("una leche", 1, "leche"),
        ("cinco leches", 5, "leches"),
        ("10 de arroz", 10, "arroz"),
        ("un paquete de arroz integral", 1, "arroz integral"),
        ("  3   botellas  de agua ", 3, "agua"),
        ("Dos Unidades De Huevos", 2, "Huevos"),
        ("5 U de leche", 5, "leche"),
        ("3 uds de yogur", 3, "yogur"),
        ("2 kilos de patatas", 2, "patatas"),
    ])
    func conUnidades(texto: String, unidades: Int, producto: String) {
        #expect(PeticionVoz.separar(texto) == PeticionVoz.Partes(unidades: unidades, producto: producto))
    }

    @Test(arguments: ["leche", "Pilas 2", "7up", "dos", "0 leches", "unidades de leche"])
    func sinUnidades(texto: String) {
        #expect(PeticionVoz.separar(texto) == PeticionVoz.Partes(unidades: nil, producto: texto))
    }

    /// «2 de» sin nada detrás no deja el producto vacío.
    @Test func noSeQuedaSinProducto() {
        #expect(PeticionVoz.separar("2 latas") == PeticionVoz.Partes(unidades: 2, producto: "latas"))
        #expect(PeticionVoz.separar("2 de") == PeticionVoz.Partes(unidades: 2, producto: "de"))
    }
}
