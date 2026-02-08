# 📱 Inventario Casa - App React Native

Aplicación móvil para iOS para gestionar el inventario del hogar con **sincronización en tiempo real** usando Firebase Firestore. Optimizada para **accesibilidad con VoiceOver**.

---

## ✨ Características

- 🛒 **Lista de la Compra Automática** - Productos con 2 unidades o menos se añaden automáticamente
- ✅ **Sincronización en tiempo real** entre múltiples dispositivos
- ✅ **Funciona offline** - Los cambios se sincronizan automáticamente cuando hay conexión
- ✅ **100% accesible con VoiceOver**
  - Acciones del rotor personalizadas (deslizar arriba/abajo para incrementar/decrementar)
  - Selector de cantidad con gestos táctiles
  - Anuncios automáticos de cambios
  - Navegación optimizada
- ✅ **Interfaz simple y clara**
  - Navegación por pestañas: Inventario y Lista de Compra
  - Campo de cantidad con selector táctil (0-99 unidades)
  - Botones grandes y táctiles
  - Sin servidor propio necesario

---

## 🚀 Instalación y Configuración

### Paso 1: Instalar dependencias

Abre una terminal en la carpeta del proyecto y ejecuta:

```powershell
cd inventario-mobile
npm install
```

### Paso 2: Configurar Firebase

1. **Crear proyecto en Firebase:**
   - Ve a https://console.firebase.google.com/
   - Clic en "Agregar proyecto"
   - Nombre: "Inventario Casa" (o el que prefieras)
   - Desactiva Google Analytics (no es necesario)
   - Clic en "Crear proyecto"

2. **Obtener credenciales:**
   - En el panel de Firebase, clic en el ícono web `</>`
   - Registra la app: nombre "Inventario Casa"
   - **Copia las credenciales** que aparecen

3. **Configurar la app:**
   - Copia el archivo `firebase-config.example.js` a `firebase-config.js`:
     ```powershell
     Copy-Item firebase-config.example.js firebase-config.js
     ```
   - Abre `firebase-config.js` y pega tus credenciales de Firebase

4. **Crear base de datos Firestore:**
   - En Firebase Console, ve a "Firestore Database"
   - Clic en "Crear base de datos"
   - Selecciona "Modo de prueba" (por ahora)
   - Ubicación: elige la más cercana
   - Clic en "Habilitar"

5. **⚠️ Configurar reglas de seguridad:**
   - En Firestore, ve a la pestaña "Reglas"
   - **Para desarrollo/pruebas**, usa estas reglas (permite acceso sin autenticación):
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if true;
         }
       }
     }
     ```
   - Clic en "Publicar"
   - **⚠️ IMPORTANTE:** Estas reglas son solo para desarrollo. Ver [SEGURIDAD-FIREBASE.md](SEGURIDAD-FIREBASE.md) para opciones de seguridad en producción.
   - **OPCIONAL:** Si necesitas autenticación en el futuro, consulta [AUTENTICACION-PENDIENTE.md](AUTENTICACION-PENDIENTE.md)

### Paso 3: Ejecutar la aplicación

```powershell
npm start
```

Esto abrirá Expo. Opciones:

- **Para iPhone físico:** Descarga "Expo Go" de la App Store, escanea el QR
- **Para simulador iOS:** Presiona `i` en la terminal (requiere Xcode en Mac)
- **Para probar en web:** Presiona `w` en la terminal

---

## 📱 Uso con VoiceOver

### Navegación Principal:
- **Pestaña Inventario:** Gestión de categorías y productos
- **Pestaña Lista de Compra:** Productos con 2 unidades o menos (automático)
- **Cambiar de pestaña:** Desliza izquierda/derecha en la barra inferior

### Pantalla de Categorías:
- **Navegar:** Desliza izquierda/derecha
- **Ver productos:** Toca dos veces sobre una categoría
- **Acciones del rotor:**
  - "Editar categoría" - Cambiar nombre
  - "Eliminar categoría" - Borrar con confirmación
- **Añadir categoría:** Botón + en la esquina inferior derecha

### Pantalla de Productos:
- **Navegar:** Desliza izquierda/derecha
- **Acciones del rotor en cada producto:**
  - **Deslizar arriba:** Incrementar cantidad (+1)
  - **Deslizar abajo:** Decrementar cantidad (-1)
  - "Editar producto" - Cambiar nombre/cantidad
  - "Eliminar producto" - Borrar con confirmación
- **Botones individuales también disponibles:** −, + y Editar
- **Añadir producto:** Botón + en la esquina inferior derecha

### Lista de la Compra:
- **Visualización automática:** Productos con ≤ 2 unidades aparecen aquí automáticamente
- **Productos urgentes:** Los que tienen 0 unidades se destacan en rojo
- **Incrementar/Decrementar:** Mismas acciones del rotor que en Productos
- **Desaparece automáticamente:** Cuando un producto supera 2 unidades, sale de la lista
- **Contador:** Muestra cuántos productos necesitas comprar

### Formularios:
- **Auto-focus:** El teclado aparece automáticamente
- **Navegación:** Tab o deslizar para cambiar de campo
- **Contador de caracteres:** Anunciado automáticamente
- **Validación:** Errores anunciados por VoiceOver

---

## 🔄 Sincronización entre Dispositivos

### Cómo funciona:
1. Ambos usuarios usan **la misma cuenta de Firebase**
2. Cualquier cambio se refleja **instantáneamente** en el otro dispositivo
3. VoiceOver anuncia: "Categorías actualizadas" cuando hay cambios

### Configurar en el segundo iPhone:
1. Instala "Expo Go" de la App Store
2. Escanea el mismo QR que en el primer dispositivo
3. **Usa el mismo archivo `firebase-config.js`** (mismas credenciales)
4. ¡Listo! Ambos verán los mismos datos

---

## 🏗️ Estructura del Proyecto

```
inventario-mobile/
├── App.js                          # Navegación principal (Tabs + Stack)
├── package.json                    # Dependencias
├── app.json                        # Configuración de Expo
├── eas.json                        # Configuración de EAS Build
├── firebase-config.js              # TUS credenciales (no subir a Git)
├── firebase-config.example.js      # Plantilla de configuración
├── firestore.rules                 # Reglas de seguridad
├── ACCESIBILIDAD.md                # Guía de accesibilidad
├── SEGURIDAD-FIREBASE.md           # Opciones de seguridad
├── AUTENTICACION-PENDIENTE.md      # Guía para añadir auth (futuro)
├── COMPILACION-APP.md              # Guía para compilar sin Mac
└── src/
    ├── services/
    │   ├── firebase.js             # Inicialización de Firebase
    │   └── firestore.js            # Funciones de base de datos
    └── screens/
        ├── CategoriasScreen.js     # Lista de categorías
        ├── ProductosScreen.js      # Lista de productos
        ├── ListaCompraScreen.js    # Lista de compra automática
        ├── NuevaCategoriaScreen.js # Formulario nueva categoría
        ├── EditarCategoriaScreen.js# Formulario editar categoría
        ├── NuevoProductoScreen.js  # Formulario nuevo producto
        └── EditarProductoScreen.js # Formulario editar producto
```

---

## 🐛 Solución de Problemas

### "Firebase not configured"
- Verifica que `firebase-config.js` existe y tiene las credenciales correctas
- Las credenciales deben venir de tu proyecto en Firebase Console

### "No se pueden ver los cambios del otro dispositivo"
- Ambos dispositivos deben usar **las mismas credenciales de Firebase**
- Verifica que ambos tienen conexión a internet
- Revisa las reglas de Firestore (deben permitir lectura/escritura)

### "La app no se abre en el iPhone"
- Asegúrate de tener "Expo Go" instalado desde la App Store
- Verifica que el iPhone y la computadora están en la misma red WiFi
- Escanea de nuevo el QR desde Expo

### VoiceOver no anuncia los cambios
- Asegúrate de estar en iOS (Android usa TalkBack diferente)
- Verifica que VoiceOver esté activado: Ajustes > Accesibilidad > VoiceOver

---

## 📦 Compilar para Uso Fuera de Casa

Para usar la app sin Expo Go y con datos móviles, necesitas compilarla como una app nativa:

```powershell
# Instalar EAS CLI
npm install -g eas-cli

# Configurar cuenta de Expo
eas login

# Compilar para iOS
eas build --platform ios
```

**⚠️ Nota importante:**
- Requiere una cuenta de **Apple Developer** ($99/año)
- Permite distribuir la app via **TestFlight** (hasta 10,000 usuarios beta)
- La app funcionará con **datos móviles** fuera de casa
- **No necesitas Mac** - todo se compila en la nube

📖 **Guía completa:** Ver [COMPILACION-APP.md](COMPILACION-APP.md) para instrucciones detalladas.

---

## 🔒 Seguridad

### ⚠️ Desarrollo (configuración actual):
```javascript
// Permite acceso sin autenticación - SOLO para desarrollo/pruebas
allow read, write: if true;
```

### 🔐 Producción (recomendado):
Para uso permanente o compartido, **añade autenticación** y actualiza las reglas:

**Opción 1: Autenticación obligatoria**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Solo usuarios autenticados
      allow read, write: if request.auth != null;
    }
  }
}
```

**Opción 2: Acceso limitado por tiempo** (para evaluación temporal)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Acceso hasta una fecha específica
      allow read, write: if request.time < timestamp.date(2026, 3, 1);
    }
  }
}
```

📖 **Ver [SEGURIDAD-FIREBASE.md](SEGURIDAD-FIREBASE.md)** para más opciones de seguridad.

📖 **Ver [AUTENTICACION-PENDIENTE.md](AUTENTICACION-PENDIENTE.md)** para implementar autenticación (Email/Password, Google, o nativa).

---

## 📞 Contacto y Soporte

- Firebase Console: https://console.firebase.google.com/
- Expo Documentation: https://docs.expo.dev/
- React Native Accessibility: https://reactnative.dev/docs/accessibility

---

## 📝 Licencia

Proyecto personal - Uso libre

---

**¡Disfruta tu app de inventario! 🎉**
