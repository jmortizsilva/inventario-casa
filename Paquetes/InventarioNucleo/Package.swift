// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InventarioNucleo",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InventarioNucleo", targets: ["InventarioNucleo"]),
        .library(name: "InventarioAlmacen", targets: ["InventarioAlmacen"]),
    ],
    targets: [
        // Las pruebas viven en `pruebas/`, junto al código que prueban,
        // por eso se excluyen de cada target principal.
        .target(
            name: "InventarioNucleo",
            exclude: ["pruebas"]
        ),
        .testTarget(
            name: "InventarioNucleoPruebas",
            dependencies: ["InventarioNucleo"],
            path: "Sources/InventarioNucleo/pruebas",
            resources: [.copy("Recursos")]
        ),
        // SwiftData separado del núcleo: el núcleo no depende de cómo se guarda.
        .target(
            name: "InventarioAlmacen",
            dependencies: ["InventarioNucleo"],
            exclude: ["pruebas"]
        ),
        .testTarget(
            name: "InventarioAlmacenPruebas",
            dependencies: ["InventarioAlmacen"],
            path: "Sources/InventarioAlmacen/pruebas"
        ),
    ]
)
