import Foundation

/// Encontrar productos y categorías por lo que dice alguien a Siri o escribe
/// en Atajos. Devuelve todo lo que encaja, ordenado: si hay más de uno, Siri
/// pregunta cuál.
public enum Busqueda {
    public static func productos(_ texto: String, en productos: [Producto]) -> [Producto] {
        coincidencias(texto, en: productos.filter { !$0.estaBorrado }, nombre: \.nombre)
    }

    public static func categorias(_ texto: String, en categorias: [Categoria]) -> [Categoria] {
        coincidencias(texto, en: categorias.filter { !$0.estaBorrada }, nombre: \.nombre)
    }

    /// Por orden, se queda con el primer grupo que no esté vacío:
    /// 1. el mismo nombre, sin mayúsculas ni tildes;
    /// 2. el mismo nombre en singular o plural («huevos» y «Huevo»);
    /// 3. los que contienen todas las palabras dichas («leche» y «Leche entera»).
    static func coincidencias<T>(_ texto: String, en elementos: [T], nombre: (T) -> String) -> [T] {
        let buscada = Nombres.clave(texto)
        guard !buscada.isEmpty else { return [] }
        let ordenados = elementos.sorted { Nombres.vaAntes(nombre($0), nombre($1)) }

        let iguales = ordenados.filter { Nombres.clave(nombre($0)) == buscada }
        if !iguales.isEmpty { return iguales }

        let formas = singulares(buscada)
        let enOtroNumero = ordenados.filter { !singulares(Nombres.clave(nombre($0))).isDisjoint(with: formas) }
        if !enOtroNumero.isEmpty { return enOtroNumero }

        let palabras = buscada.split(separator: " ")
        return ordenados.filter { elemento in
            let clave = Nombres.clave(nombre(elemento))
            return palabras.allSatisfy { clave.contains($0) }
        }
    }

    /// Las formas que puede tener la palabra en singular: tal cual, sin «s» y
    /// sin «es». «leches» da leche; «limones», limon; «pan» se queda en pan.
    /// Sobran formas que no existen («lech»), pero solo sirven para comparar.
    private static func singulares(_ clave: String) -> Set<String> {
        var formas: Set<String> = [clave]
        if clave.hasSuffix("s") { formas.insert(String(clave.dropLast())) }
        if clave.hasSuffix("es") { formas.insert(String(clave.dropLast(2))) }
        return formas
    }
}
