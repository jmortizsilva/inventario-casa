// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InventarioNucleo",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InventarioNucleo", targets: ["InventarioNucleo"]),
    ],
    targets: [
        // Las pruebas viven en `pruebas/`, junto al código que prueban,
        // por eso se excluyen del target principal.
        .target(
            name: "InventarioNucleo",
            exclude: ["pruebas"]
        ),
        .testTarget(
            name: "InventarioNucleoPruebas",
            dependencies: ["InventarioNucleo"],
            path: "Sources/InventarioNucleo/pruebas"
        ),
    ]
)
