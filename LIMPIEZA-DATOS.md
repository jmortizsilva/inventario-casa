# Limpieza segura de datos Firestore

Script: scripts/firestore-safe-cleanup.js

## Objetivo

Auditar y corregir datos anómalos sin tocar datos por defecto.

## Modo seguro por defecto

- Si no usas --apply, el script solo audita (dry-run).
- En --apply, el backup esta activado por defecto.
- No fusiona duplicados salvo que añadas --fix-duplicates.

## Requisitos

- Credenciales de service account con permisos de Firestore Admin.
- Variable de entorno GOOGLE_APPLICATION_CREDENTIALS, o flag --service-account.

## Comandos recomendados

1. Auditoria global

```powershell
npm run cleanup:audit -- --service-account="C:\ruta\service-account.json"
```

2. Auditoria de un hogar concreto

```powershell
npm run cleanup:audit -- --service-account="C:\ruta\service-account.json" --household-id=HOUSEHOLD_ID
```

3. Auditoria incluyendo legacy top-level

```powershell
npm run cleanup:audit -- --service-account="C:\ruta\service-account.json" --include-legacy --user-id=USER_UID
```

4. Aplicar fixes en un hogar (con backup)

```powershell
npm run cleanup:apply -- --service-account="C:\ruta\service-account.json" --household-id=HOUSEHOLD_ID
```

5. Aplicar y fusionar duplicados

```powershell
npm run cleanup:apply -- --service-account="C:\ruta\service-account.json" --household-id=HOUSEHOLD_ID --fix-duplicates
```

6. Limpiar legacy no perteneciente a un usuario

```powershell
npm run cleanup:apply -- --service-account="C:\ruta\service-account.json" --cleanup-legacy --user-id=USER_UID
```

## Que corrige

- Productos huerfanos (categoria inexistente).
- Cantidades invalidas o negativas.
- Duplicados de categorias (opcional, con --fix-duplicates).
- Duplicados de productos por categoria+nombre (opcional, con --fix-duplicates).
- Documentos legacy top-level no pertenecientes al usuario indicado (opcional).

## Precaucion

En hogares con datos reales, usa siempre primero auditoria y revisa el JSON generado antes de aplicar.
