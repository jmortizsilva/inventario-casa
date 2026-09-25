import Testing
@testable import InventarioNucleo

@Test func laVersionNoEstaVacia() {
    #expect(!Nucleo.version.isEmpty)
}
