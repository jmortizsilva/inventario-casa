# Inventario Casa (iOS nativa)

- Swift 6 y SwiftUI, iOS 17 como mínimo. Persistencia local con SwiftData.
- El proyecto usa carpetas sincronizadas de Xcode: los ficheros que se añaden en `InventarioCasa/` entran solos en el target. No hace falta tocar `project.pbxproj`.
- La lógica que decide (regla de la lista de la compra, validaciones, textos que se anuncian) va en `Paquetes/InventarioNucleo`, sin importar SwiftUI ni SwiftData, y se prueba con Swift Testing.
- Las pruebas del paquete están en `Sources/InventarioNucleo/pruebas/`. El target principal las excluye en `Package.swift`.
- Más adelante habrá app de Android y servidor propio: los casos de prueba de la lógica compartida se escriben en JSON (`pruebas/Recursos/`) para que los use también Kotlin.
- El modelo del núcleo son structs. `Inventario` (en el núcleo) decide y guarda a través del protocolo `Almacen`; `InventarioAlmacen` es la implementación con SwiftData, sin decisiones propias. `AlmacenEnMemoria` sirve para pruebas y vistas previas.
- El esquema de SwiftData está versionado (`EsquemaV1`). Un cambio de modelo añade `EsquemaV2` y una etapa en `PlanMigracion`; no se toca la versión anterior.
- Nombres: `.diacriticInsensitive` convierte la ñ en n («Año» = «ano»), por eso `Nombres.clave` quita tildes letra a letra. Para ordenar, `compare` con `.caseInsensitive` y `Locale("es_ES")` ya pone la ñ detrás de la n.
- Textos de interfaz y vocabulario (Añadir, Quitar, Eliminar…): `docs/textos-interfaz.md`. Todos viven en `Textos.swift` con pruebas; un cambio de texto toca los tres sitios a la vez.

## Verificación

```bash
cd Paquetes/InventarioNucleo && swift test
xcodebuild -project InventarioCasa.xcodeproj -scheme InventarioCasa \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' build
```

```bash
# Pruebas del paquete en el simulador (SwiftData del sistema de verdad)
cd Paquetes/InventarioNucleo && xcodebuild test -scheme InventarioNucleo-Package \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
```

Compilar para el simulador de iOS 17.5 comprueba que no se usa nada posterior a la versión mínima.
