# 📱 Guía para Compilar la App (Sin Mac)

Esta guía explica cómo compilar la app de Inventario Casa para iPhone usando **EAS Build** (Expo Application Services) sin necesitar una Mac.

---

## ¿Qué es EAS Build?

EAS Build es un servicio en la nube de Expo que compila tu app de React Native en servidores remotos. Esto significa que:
- ✅ **No necesitas Mac** - Todo se compila en la nube
- ✅ **No necesitas Xcode** - EAS se encarga de todo
- ✅ **Puedes distribuir la app** vía TestFlight o instalación directa (Ad-Hoc)

---

## 📋 Requisitos Previos

### 1. Cuenta de Expo (Gratis)
Si no tienes una, créala en: https://expo.dev/signup

### 2. Cuenta de Apple Developer (De pago)
**Necesitas UNA de estas opciones:**

**Opción A: Apple Developer Program - $99/año (RECOMENDADO)**
- Permite distribución via TestFlight (la forma más fácil)
- Permite publicar en App Store si quieres
- Puedes compartir la app con hasta 10,000 usuarios beta

**Opción B: Cuenta Apple ID gratuita (LIMITADO)**
- Solo puedes instalar en TU iPhone (máximo 3 dispositivos)
- La app caduca cada 7 días (hay que reinstalar)
- No puedes compartir con otros
- **NO RECOMENDADO** si quieres compartir con tu chica

---

## 🚀 Instalación y Configuración

### Paso 1: Instalar EAS CLI

Abre PowerShell/Terminal y ejecuta:

```powershell
npm install -g eas-cli
```

Verifica la instalación:
```powershell
eas --version
```

### Paso 2: Iniciar sesión en Expo

```powershell
eas login
```

Ingresa tu email y contraseña de Expo.

### Paso 3: Configurar el proyecto

En la carpeta del proyecto (`inventario-mobile`), ejecuta:

```powershell
eas build:configure
```

Esto creará un archivo `eas.json` con la configuración de builds.

### Paso 4: Configurar credenciales de Apple

EAS necesita tus credenciales de Apple Developer. Tienes dos opciones:

**Opción A: Dejar que EAS maneje todo (FÁCIL)**
```powershell
eas build --platform ios
```
EAS te pedirá tu Apple ID y contraseña, y se encargará de crear certificados automáticamente.

**Opción B: Usar credenciales manuales (MANUAL)**
Si ya tienes certificados de desarrollo, puedes cargarlos manualmente:
```powershell
eas credentials
```

---

## 📦 Crear el Build

### Para instalar en tu iPhone (Development Build)

```powershell
eas build --platform ios --profile development
```

**¿Qué hace esto?**
- Compila la app en los servidores de Expo
- Crea un archivo `.ipa` que puedes instalar en iPhones registrados
- Tarda aproximadamente 15-25 minutos

### Para distribución via TestFlight (Recomendado)

```powershell
eas build --platform ios --profile production
```

**¿Qué hace esto?**
- Compila la app para distribución
- La sube automáticamente a App Store Connect
- Desde ahí puedes distribuirla via TestFlight a otros usuarios

---

## 📲 Instalar la App en iPhone

### Opción 1: Usando el enlace de EAS (Más Fácil)

1. Una vez que el build termine, EAS te dará un enlace como:
   ```
   https://expo.dev/artifacts/eas/[id].ipa
   ```

2. **En tu iPhone**:
   - Abre Safari
   - Ve al enlace que te dio EAS
   - Toca "Instalar"
   - Ve a Ajustes > General > Gestión de Dispositivos
   - Confía en el perfil de desarrollador

### Opción 2: Via TestFlight (Mejor para compartir)

1. Sube el build a TestFlight:
   ```powershell
   eas submit --platform ios
   ```

2. En App Store Connect:
   - Ve a TestFlight
   - Añade testers (tú y tu chica)
   - Envía invitaciones por email

3. Los testers:
   - Instalan la app "TestFlight" de la App Store
   - Abren el link de invitación
   - Instalan "Inventario Casa" desde TestFlight

---

## 🔧 Configuración Avanzada del `eas.json`

El archivo `eas.json` controla cómo se compila la app. Aquí un ejemplo optimizado:

```json
{
  "cli": {
    "version": ">= 13.2.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "simulator": false
      }
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "simulator": false
      }
    },
    "production": {
      "autoIncrement": true,
      "ios": {
        "simulator": false
      }
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleId": "tu-email@ejemplo.com",
        "ascAppId": "1234567890",
        "appleTeamId": "ABCD1234"
      }
    }
  }
}
```

---

## 💡 Consejos y Mejores Prácticas

### Para usar fuera de casa (datos móviles)

**La app funciona automáticamente con datos móviles** porque usa Firebase (servidor en la nube). No necesitas estar en la misma red WiFi.

### Para actualizar la app

**Con Expo Updates (Actualizaciones Over-The-Air):**
```powershell
# Instalar EAS Update
npm install -g expo-updates

# Publicar actualización
eas update --branch production --message "Nuevas mejoras"
```

**Los cambios se verán inmediatamente** sin necesidad de recompilar. Perfecto para:
- Cambios en el código JavaScript/React
- Ajustes de estilos y textos
- Correcciones de bugs

**NO funciona para:**
- Añadir nuevas librerías nativas
- Cambiar configuración de app.json

Para esos casos, necesitas crear un nuevo build con `eas build`.

### Administrar dispositivos

Para añadir nuevos iPhones al perfil de desarrollo:
```powershell
eas device:create
```

EAS te dará un link donde puedes registrar el UDID del iPhone nuevo.

---

## 🛠️ Troubleshooting

### "Build failed - Invalid provisioning profile"
**Solución:** Ejecuta `eas credentials` y regenera los certificados.

### "No Apple Developer account found"
**Solución:** Necesitas una cuenta de Apple Developer ($99/año). No hay forma de evitar esto para distribución real.

### "Build queue is busy"
**Solución:** Espera tu turno. Los builds gratuitos de Expo tienen prioridad más baja.

### "App installs but crashes immediately"
**Solución:** Verifica que `firebase-config.js` tenga las credenciales correctas antes del build.

---

## 📊 Costos

| Servicio | Costo |
|----------|-------|
| Expo Free Tier | **Gratis** - 30 builds/mes |
| EAS Build | Primer tier gratis suficiente |
| Apple Developer | **$99/año** (necesario para distribución seria) |
| Firebase | **Gratis** hasta 50K lecturas/día |

**Total estimado: $99/año** (solo Apple Developer)

---

## 🔗 Enlaces Útiles

- EAS Build Documentation: https://docs.expo.dev/build/introduction/
- Apple Developer: https://developer.apple.com/programs/
- EAS Pricing: https://expo.dev/pricing
- TestFlight: https://developer.apple.com/testflight/

---

## 📝 Resumen de Comandos

```powershell
# Instalación inicial
npm install -g eas-cli
eas login
eas build:configure

# Crear build para desarrollo (instalar directo)
eas build --platform ios --profile development

# Crear build para producción (via TestFlight)
eas build --platform ios --profile production

# Ver builds anteriores
eas build:list

# Subir a TestFlight
eas submit --platform ios

# Registrar nuevo dispositivo
eas device:create

# Publicar actualización OTA
eas update --branch production
```

---

**¿Necesitas ayuda?** Consulta la documentación de Expo o abre un issue en el repositorio.
