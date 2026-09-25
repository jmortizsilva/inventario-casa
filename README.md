# Inventario Casa

App para iOS que lleva el inventario de casa por categorías y productos, con lista de la compra.

Esta rama (`app-nativa`) es la versión nativa en Swift y SwiftUI. La versión anterior, en React Native con Expo y Firebase, está en `main` y marcada con la etiqueta `expo-final`.

## Estructura

- `InventarioCasa/`: la app (vistas SwiftUI).
- `Paquetes/InventarioNucleo/`: modelo y lógica sin interfaz, con sus pruebas en `pruebas/`.

## Requisitos

- Xcode 27 o posterior.
- iOS 17 como mínimo.

## Comprobar

```bash
# Pruebas del núcleo
cd Paquetes/InventarioNucleo && swift test

# Compilar la app
xcodebuild -project InventarioCasa.xcodeproj -scheme InventarioCasa \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```
