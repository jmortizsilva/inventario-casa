# Inventario Casa (iOS nativa)

- Swift 6 y SwiftUI, iOS 17 como mínimo. Persistencia local con SwiftData.
- El proyecto usa carpetas sincronizadas de Xcode: los ficheros que se añaden en `InventarioCasa/` entran solos en el target. No hace falta tocar `project.pbxproj`.
- La lógica que decide (regla de la lista de la compra, validaciones, textos que se anuncian) va en `Paquetes/InventarioNucleo`, sin importar SwiftUI ni SwiftData, y se prueba con Swift Testing.
- Las pruebas del paquete están en `Sources/InventarioNucleo/pruebas/`. El target principal las excluye en `Package.swift`.
- Más adelante habrá app de Android y servidor propio: los casos de prueba de la lógica compartida se escriben en JSON (`pruebas/Recursos/`) para que los use también Kotlin.
- El modelo del núcleo son structs; SwiftData se queda en la app y convierte a y desde ellas.
- Nombres: `.diacriticInsensitive` convierte la ñ en n («Año» = «ano»), por eso `Nombres.clave` quita tildes letra a letra. Para ordenar, `compare` con `.caseInsensitive` y `Locale("es_ES")` ya pone la ñ detrás de la n.

## Verificación

```bash
cd Paquetes/InventarioNucleo && swift test
xcodebuild -project InventarioCasa.xcodeproj -scheme InventarioCasa \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' build
```

Compilar para el simulador de iOS 17.5 comprueba que no se usa nada posterior a la versión mínima.
