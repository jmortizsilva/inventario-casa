import AppIntents

/// Las frases que Siri reconoce sin que el usuario configure nada. Siri exige
/// el nombre de la app en cada una. Los productos de las frases salen de
/// `ConsultaProductos.suggestedEntities`, y hay que avisar al sistema cuando
/// cambian (`updateAppShortcutParameters`).
struct Atajos: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnadirUnidades(),
            phrases: [
                "Añade \(\.$producto) en \(.applicationName)",
                "He comprado \(\.$producto) en \(.applicationName)",
            ],
            shortTitle: "Añadir unidades",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: QuitarUnidades(),
            phrases: [
                "Quita \(\.$producto) en \(.applicationName)",
                "He gastado \(\.$producto) en \(.applicationName)",
            ],
            shortTitle: "Quitar unidades",
            systemImageName: "minus.circle"
        )
        AppShortcut(
            intent: CambiarCantidad(),
            phrases: ["Cambia la cantidad de \(\.$producto) en \(.applicationName)"],
            shortTitle: "Cambiar la cantidad",
            systemImageName: "number.circle"
        )
        AppShortcut(
            intent: ConsultarProducto(),
            phrases: [
                "¿Cuántas unidades de \(\.$producto) hay en \(.applicationName)?",
                "Consulta \(\.$producto) en \(.applicationName)",
            ],
            shortTitle: "Consultar un producto",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: CrearProducto(),
            phrases: ["Crea un producto en \(.applicationName)"],
            shortTitle: "Crear producto",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: EliminarProducto(),
            phrases: ["Elimina \(\.$producto) de \(.applicationName)"],
            shortTitle: "Eliminar producto",
            systemImageName: "trash"
        )
    }
}
