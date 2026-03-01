# Publicar para testers externos en TestFlight

Esta guía es para permitir pruebas a personas fuera del equipo interno.

## 1) Subir build de producción

```powershell
npx eas-cli build --platform ios --profile production --clear-cache
npx eas-cli submit --platform ios --profile production --latest
```

## 2) Esperar procesamiento en App Store Connect

- En App Store Connect → TestFlight.
- Estado inicial: `Processing`.
- Cuando termine, la build pasa a disponible para testing.

## 3) Completar metadatos de cumplimiento si los pide

Según el estado de la app, Apple puede solicitar:
- Export compliance
- Información de contenido
- Notas para revisión beta

## 4) Crear grupo de testers externos

- TestFlight → `External Testing` → crear grupo.
- Añadir testers por email o generar enlace público.

## 5) Enviar a revisión Beta App Review (primera vez)

Para testers externos, Apple suele requerir revisión previa de la build.

- Seleccionar build en el grupo.
- `Submit for Review`.
- Esperar aprobación (normalmente horas, puede variar).

## 6) Activar distribución

Cuando Apple apruebe:
- Habilitar testers o enlace público.
- Los usuarios instalan desde la app TestFlight.

## Importante

- Testers internos: no requieren Beta App Review.
- Testers externos: sí requieren revisión de la build.
- Si subes nueva build, hay que asignarla al grupo externo; puede requerir nueva revisión según cambios.
