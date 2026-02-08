# Guía Rápida de Inicio

## 1. Instalar dependencias
```powershell
cd inventario-mobile
npm install
```

## 2. Configurar Firebase (5 minutos)

### A. Crear proyecto:
1. https://console.firebase.google.com/ → "Agregar proyecto"
2. Nombre: "Inventario Casa"
3. Desactiva Analytics → Crear

### B. Registrar app web:
1. Clic en ícono `</>`
2. Nombre: "Inventario Casa"
3. **Copiar las credenciales**

### C. Configurar credenciales:
```powershell
Copy-Item firebase-config.example.js firebase-config.js
```
Abre `firebase-config.js` y pega tus credenciales.

### D. Crear Firestore:
1. Firestore Database → Crear base de datos
2. Modo: "Prueba"
3. Ubicación: la más cercana
4. Habilitar

## 3. Ejecutar
```powershell
npm start
```

- **iPhone físico:** Descarga "Expo Go" → Escanea QR
- **Web:** Presiona `w` en la terminal

## 4. Segundo dispositivo
- Usa el **mismo QR** y **mismo firebase-config.js**
- ¡La sincronización es automática!

---

## Accesibilidad VoiceOver

### En productos:
- **Deslizar arriba** = Incrementar cantidad
- **Deslizar abajo** = Decrementar cantidad  
- **Acción "Editar"** = Modificar producto
- **Acción "Eliminar"** = Borrar producto

### Botones visibles:
- **−** = Decrementar
- **+** = Incrementar
- **✎** = Editar (mantén presionado para eliminar)

---

¿Problemas? Lee el README.md completo.
