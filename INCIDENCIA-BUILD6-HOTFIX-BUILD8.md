# Incidencia build 6 y hotfix para build 8

## Resumen ejecutivo

Se detectó una regresión entre build 5 y build 6 en iOS: la app podía cerrarse tras autenticación con Google.

- Build 5 (production): versión 1.0.0, commit `2097cd0`
- Build 6 (production): versión 1.0.1, commit `830247a`

## Síntoma

- El usuario completa login con Google.
- Al volver a la app, se produce cierre/crash en el acceso a pantallas principales.

## Análisis

El cambio más probable y reproducible se localizó en las pantallas con scroll:

- `src/screens/CategoriasScreen.js`
- `src/screens/ListaCompraScreen.js`
- `src/screens/ProductosScreen.js`

Estas pantallas usaban `useBottomTabBarHeight` de `@react-navigation/bottom-tabs`, mientras el contenedor de pestañas en la app está basado en `@bottom-tabs/react-navigation`.

Esa combinación puede dejar el hook fuera de su contexto esperado y provocar fallo en runtime.

## Hotfix aplicado

1. Eliminado `useBottomTabBarHeight` en las 3 pantallas afectadas.
2. Sustituido por padding inferior estable (sin dependencia del contexto de tabs).
3. Mantenida versión de aplicación en `1.0.0` para seguir la línea de compilaciones.

## Resultado de validación

- Build `preview` con versión `1.0.0` validado como funcional.
- Login con Google operativo y navegación estable.

## Publicación prevista

- Build `production` siguiente: **build 8** (auto-increment en `eas.json`).
- Comando:

```powershell
npx eas-cli build --platform ios --profile production --clear-cache
```

- Envío a TestFlight:

```powershell
npx eas-cli submit --platform ios --profile production --latest
```
