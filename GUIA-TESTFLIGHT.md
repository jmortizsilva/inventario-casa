# 📱 Guía para Subir a TestFlight sin Mac

## Requisitos Previos
- ✅ Cuenta de Apple Developer (99 USD/año)
- ✅ Cuenta de Expo
- ✅ EAS CLI instalado

## Paso 1: Instalar EAS CLI
```bash
npm install -g eas-cli
```

## Paso 2: Iniciar sesión en Expo
```bash
eas login
```

## Paso 3: Configurar Credenciales de Apple

### 3.1 Obtener tu Team ID
1. Ve a [Apple Developer](https://developer.apple.com/account)
2. En "Membership", copia tu **Team ID**
3. Actualiza `eas.json` con este Team ID

### 3.2 Crear la App en App Store Connect
1. Ve a [App Store Connect](https://appstoreconnect.apple.com)
2. Click en "Apps" → "+" → "Nueva App"
3. Datos necesarios:
   - **Plataforma**: iOS
   - **Nombre**: Inventario Casa
   - **Idioma principal**: Español
   - **Bundle ID**: `com.jmortiz.inventario` (crear nuevo)
   - **SKU**: inventario-casa-2026 (puede ser cualquier texto único)
4. Copia el **App Store ID** (aparece en la URL o en "Información de la app")

### 3.3 Actualizar eas.json
Edita `eas.json` con tus datos reales:
```json
"submit": {
  "production": {
    "ios": {
      "appleId": "tu-email@apple.com",
      "ascAppId": "6123456789",
      "appleTeamId": "ABC123DEFG"
    }
  }
}
```

## Paso 4: Compilar la App (Build)

### Para TestFlight (recomendado para pruebas):
```bash
cd inventario-mobile
eas build --platform ios --profile preview
```

Durante el proceso:
- Te pedirá acceso a tu cuenta de Apple Developer
- Creará automáticamente los certificados y perfiles
- Compilará la app en la nube (tarda ~10-15 minutos)

### Para producción:
```bash
eas build --platform ios --profile production
```

## Paso 5: Subir a TestFlight
```bash
eas submit --platform ios
```

Durante el proceso:
- Selecciona el build que acabas de crear
- EAS lo subirá automáticamente a App Store Connect
- Aparecerá en TestFlight en ~15-30 minutos

## Paso 6: Invitar Testers

### En App Store Connect:
1. Ve a "TestFlight"
2. Click en tu app
3. En "Testers Internos" o "Testers Externos":
   - Click "+" para añadir testers
   - Ingresa sus emails
4. Ellos recibirán un email con invitación
5. Descargan TestFlight desde App Store
6. Instalan tu app

### Límites:
- **Internos**: Hasta 100 testers (miembros de tu equipo)
- **Externos**: Hasta 10,000 testers (requiere revisión de Apple, ~24-48h)

## Paso 7: Actualizar la App

Cuando hagas cambios:

1. **Incrementa la versión** en `app.json`:
```json
"version": "1.0.1"
```

2. **Compila nuevamente**:
```bash
eas build --platform ios --profile preview
```

3. **Sube a TestFlight**:
```bash
eas submit --platform ios
```

## Comandos Útiles

```bash
# Ver tus builds
eas build:list

# Ver el estado de un build
eas build:view [BUILD_ID]

# Cancelar un build
eas build:cancel [BUILD_ID]

# Ver configuración actual
eas build:configure
```

## Troubleshooting

### Error: "No credentials found"
```bash
eas credentials
```
Luego selecciona iOS y configura manualmente.

### Error: "Bundle identifier is not available"
El bundle ID ya está en uso. Cambia en `app.json` y `eas.json`:
```
com.jmortiz.inventario2
```

### Build falla en Firebase
Asegúrate de que `firebase-config.js` tiene configuración válida.

### La app crashea al abrir
Revisa los logs en Xcode o usa:
```bash
eas build:view [BUILD_ID]
```

## Costos

- **Apple Developer**: 99 USD/año
- **EAS Build**: 
  - Gratis: 30 builds/mes
  - Paid: Ilimitado desde $99/mes

## Recursos
- [Documentación EAS Build](https://docs.expo.dev/build/introduction/)
- [TestFlight](https://developer.apple.com/testflight/)
- [App Store Connect](https://appstoreconnect.apple.com/)

---

**Nota**: No necesitas Mac para nada de esto. EAS Build compila todo en la nube de Expo usando servidores Mac.

? Select environment: »
( )   development
( )   preview
( )   production
