# Autenticación - Estado Actual y Opciones

## ⚠️ Estado Actual

La autenticación con Google OAuth **ha sido desactivada temporalmente** porque Firebase Auth Web SDK tiene problemas de compatibilidad con React Native en Expo Go.

**Archivos modificados (comentados):**
- `App.js` - AuthProvider desactivado
- `src/contexts/AuthContext.js` - Existe pero no se usa
- `src/screens/LoginScreen.js` - Existe pero no se usa  
- `src/screens/CategoriasScreen.js` - Código de logout/usuario comentado

## 🔍 Problema Técnico

El error que aparecía era:

```
Error: Component auth has not been registered yet
```

**Causa:** Firebase Web SDK (`firebase/auth`) no está diseñado para React Native. La función `getAuth()` intenta usar APIs web que no existen en React Native.

## ✅ Opciones para Implementar Autenticación

### **Opción 1: Autenticación con Email/Contraseña (MÁS SIMPLE)**

**Ventajas:**
- Compatible con Expo Go (sin build necesario)
- Firebase Web SDK lo soporta bien en React Native
- Más simple de implementar y mantener

**Implementación:**

```javascript
// src/services/firebase.js
import { getAuth } from 'firebase/auth';
const auth = getAuth(app);

// En LoginScreen.js
import { createUserWithEmailAndPassword, signInWithEmailAndPassword } from 'firebase/auth';

const handleRegister = async (email, password) => {
  try {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    console.log('Usuario creado:', userCredential.user);
  } catch (error) {
    console.error('Error:', error.message);
  }
};

const handleLogin = async (email, password) => {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    console.log('Login exitoso:', userCredential.user);
  } catch (error) {
    console.error('Error:', error.message);
  }
};
```

**Pasos:**
1. Activar Email/Password en Firebase Console → Authentication → Sign-in method
2. Descomentar código en `App.js` y `CategoriasScreen.js`
3. Modificar `src/contexts/AuthContext.js` para usar email/password en lugar de Google
4. Modificar `src/screens/LoginScreen.js` para tener campos de email y contraseña

---

### **Opción 2: Google Sign-In con Expo Auth Session (COMPLICADO)**

**Ventajas:**
- Funciona en Expo Go
- Usa el navegador web para OAuth

**Desventajas:**
- Más complejo de configurar
- Experiencia de usuario menos fluida (abre Safari/Chrome)
- Problemas con imports de expo-auth-session

**Estado:** Ya se intentó implementar pero expo-auth-session tiene problemas con los módulos build/providers/Google

---

### **Opción 3: Build Nativo con @react-native-firebase (PROFESIONAL)**

**Ventajas:**
- Google Sign-In nativo (mejor UX)
- Mejor rendimiento
- Más funcionalidades de Firebase

**Desventajas:**
- Requiere build nativo (no funciona en Expo Go)
- Más complejo de configurar
- Necesitas EAS Build o ejection

**Pasos:**
1. Instalar `@react-native-firebase/app` y `@react-native-firebase/auth`
2. Configurar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)
3. Configurar `@react-native-google-signin/google-signin`
4. Hacer build con `eas build`

---

## 📋 Recomendación

**Para desarrollo rápido:** Usa **Opción 1** (Email/Password)
- Funciona inmediatamente en Expo Go
- Simple de implementar
- Perfecto para probar la app

**Para producción:** Migra a **Opción 3** (@react-native-firebase)
- Mejor experiencia de usuario
- Más profesional
- Acceso a todas las funcionalidades de Firebase

---

## 🔧 Para Reactivar Email/Password

1. **En Firebase Console:**
   - Authentication → Sign-in method
   - Habilitar "Email/Password"

2. **Descomentar código:**
   ```bash
   # En App.js: descomentar líneas 5-6, 19-27, 116-118
   # En CategoriasScreen.js: descomentar líneas 13, 17, 33-47, 122-124
   ```

3. **Modificar AuthContext.js:**
   - Remover código de Google OAuth
   - Agregar funciones para email/password

4. **Modificar LoginScreen.js:**
   - Cambiar botón de Google por campos de email/contraseña
   - Agregar formulario de registro

---

## 📚 Referencias

- [Firebase Auth con Email](https://firebase.google.com/docs/auth/web/password-auth)
- [React Native Firebase](https://rnfirebase.io/)
- [Expo Auth Session](https://docs.expo.dev/versions/latest/sdk/auth-session/)
- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

---

**Última actualización:** 8 de febrero de 2026

La app funciona **sin autenticación** actualmente. Los datos son públicos (cualquiera con Firestore connectado puede leer/escribir). Para proteger los datos, implementa una de las opciones anteriores y actualiza las reglas de seguridad en Firebase Console.
