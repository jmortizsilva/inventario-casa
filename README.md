# Inventario Casa

App para iOS que lleva el inventario de casa por categorías y productos, con lista de la compra.

Esta rama (`app-nativa`) es la versión nativa en Swift y SwiftUI. La versión anterior, en React Native con Expo y Firebase, está en `main` y marcada con la etiqueta `expo-final`.

## Estructura

- `InventarioCasa/`: la app (vistas SwiftUI).
- `Paquetes/InventarioNucleo/`: paquete con dos módulos, cada uno con sus pruebas en `pruebas/`:
  - `InventarioNucleo`: modelo y lógica sin interfaz.
  - `InventarioAlmacen`: guardado en el móvil con SwiftData.

- `scripts/exportar-firestore/`: exporta los datos de la versión de Expo para importarlos en la app (Ajustes → Importar datos).

## Pasar los datos de la versión de Expo

1. En la consola de Firebase: Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada. Guarda la clave fuera del repositorio.
2. Exporta:
   ```bash
   cd scripts/exportar-firestore
   npm install
   node exportar.js --clave=/ruta/a/la/clave.json
   ```
   Crea un archivo por hogar en `exportacion-firestore/`, que no se sube al repositorio. Solo lee Firestore; no cambia nada.
3. Pasa el archivo al iPhone (AirDrop, iCloud Drive…) y en la app: Ajustes → Importar datos.

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
