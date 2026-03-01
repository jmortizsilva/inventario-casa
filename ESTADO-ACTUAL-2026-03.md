# Estado actual del proyecto (marzo 2026)

Este documento refleja el estado real de la app tras la migración a autenticación Google y hogares compartidos.

## Funcionalidad principal

- Inicio de sesión con Google.
- Gestión por hogar (`households`) con código de invitación (`householdInvites`).
- Selección de hogar después del login:
  - Continuar con hogar actual
  - Unirse con código
  - Crear otro hogar
- Inventario por categorías y productos con sincronización en tiempo real.
- Lista de compra automática por umbral (`umbralCompra`) + opción manual por producto.

## Accesibilidad (VoiceOver)

- Rotor en categorías: añadir producto, editar categoría, eliminar categoría.
- Rotor en productos: editar (acción por defecto), aumentar/disminuir cantidad, lista de compra (añadir/quitar), eliminar.
- Formularios con mejoras de navegación:
  - Menos duplicidades de lectura
  - Orden de flicks corregido en edición de producto
  - Teclado no se abre automáticamente en edición de producto
- Botones `Cancelar`/`Guardar` movidos al header en pantallas de alta/edición (patrón iOS).

## Persistencia de sesión

- Firebase Auth persistente en React Native con `@react-native-async-storage/async-storage`.
- Al cerrar/reabrir app se conserva sesión (salvo cierre manual o invalidación).

## Migración de datos legacy

- Se incluye migración de datos antiguos (`categorias`/`productos` top-level) al hogar activo del usuario.
- La migración se ejecuta automáticamente cuando aplica y también manualmente desde Ajustes.

## Reglas Firestore usadas por la app

- Colecciones principales:
  - `users/{uid}`
  - `households/{householdId}`
  - `householdInvites/{inviteCode}`
- Se requiere desplegar `firestore.rules` para que unión por código y permisos funcionen correctamente.

## Flujo de release recomendado

1. Build iOS `preview` para validación funcional rápida.
2. Pruebas de VoiceOver + login + unión por código + edición.
3. Build iOS `production`.
4. Submit a TestFlight.

## Comandos útiles

```powershell
# Reglas Firestore
npx firebase-tools deploy --only firestore:rules --project inventario-casa-816a4

# Build preview iOS
$env:EAS_SKIP_AUTO_FINGERPRINT="1"
npx eas-cli build --platform ios --profile preview --clear-cache

# Build production + submit
npx eas-cli build --platform ios --profile production --clear-cache
npx eas-cli submit --platform ios --profile production --latest
```

## Notas

- `preview` (internal/ad hoc) requiere dispositivos registrados.
- Para que “cualquiera” pueda probar, usar TestFlight con testers externos.
