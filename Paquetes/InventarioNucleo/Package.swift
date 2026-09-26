// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InventarioNucleo",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InventarioNucleo", targets: ["InventarioNucleo"]),
        .library(name: "InventarioAlmacen", targets: ["InventarioAlmacen"]),
        .library(name: "InventarioConexion", targets: ["InventarioConexion"]),
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
        // Red, sesión y llavero. Sin SwiftUI: lo que necesita pantalla
        // (las hojas de Apple y de Safari) vive en la app.
        .target(
            name: "InventarioConexion",
            dependencies: ["InventarioNucleo"],
            exclude: ["pruebas"]
        ),
        .testTarget(
            name: "InventarioConexionPruebas",
            dependencies: ["InventarioConexion"],
            path: "Sources/InventarioConexion/pruebas"
        ),
    ]
)
