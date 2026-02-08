# 🔒 Configuración de Seguridad Firebase

## Paso 1: Actualizar Reglas de Firestore

1. **Ve a Firebase Console:**
   https://console.firebase.google.com/project/inventario-casa-816a4/firestore/rules

2. **Reemplaza las reglas actuales con estas:**

### Opción A: Seguridad por período de tiempo (Recomendada para pruebas)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // Permite acceso hasta el 8 de marzo de 2026
      // Después de esta fecha deberás actualizar las reglas
      allow read, write: if request.time < timestamp.date(2026, 3, 8);
    }
  }
}
```

### Opción B: Seguridad básica permanente (Para uso continuo)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Permite operaciones básicas de lectura/escritura
    match /categorias/{categoriaId} {
      allow read, write: if true;
    }
    
    match /productos/{productoId} {
      allow read, write: if true;
    }
  }
}
```

### Opción C: Seguridad avanzada con validación (Más restrictiva)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Categorías: validar estructura
    match /categorias/{categoriaId} {
      allow read: if true;
      allow create: if request.resource.data.keys().hasAll(['nombre', 'createdAt', 'updatedAt'])
                    && request.resource.data.nombre is string
                    && request.resource.data.nombre.size() > 0
                    && request.resource.data.nombre.size() <= 100;
      allow update: if request.resource.data.keys().hasAll(['nombre', 'updatedAt'])
                    && request.resource.data.nombre is string
                    && request.resource.data.nombre.size() > 0
                    && request.resource.data.nombre.size() <= 100;
      allow delete: if true;
    }
    
    // Productos: validar estructura
    match /productos/{productoId} {
      allow read: if true;
      allow create: if request.resource.data.keys().hasAll(['nombre', 'cantidad', 'categoriaId', 'createdAt', 'updatedAt'])
                    && request.resource.data.nombre is string
                    && request.resource.data.nombre.size() > 0
                    && request.resource.data.nombre.size() <= 200
                    && request.resource.data.cantidad is int
                    && request.resource.data.cantidad >= 0
                    && request.resource.data.categoriaId is string;
      allow update: if request.resource.data.keys().hasAll(['nombre', 'cantidad', 'categoriaId', 'updatedAt'])
                    && request.resource.data.nombre is string
                    && request.resource.data.nombre.size() > 0
                    && request.resource.data.nombre.size() <= 200
                    && request.resource.data.cantidad is int
                    && request.resource.data.cantidad >= 0
                    && request.resource.data.categoriaId is string;
      allow delete: if true;
    }
  }
}
```

## Paso 2: Publicar las Reglas

1. Clic en **"Publicar"** en Firebase Console
2. Las reglas se aplicarán inmediatamente

## 📝 Nota Importante

**Todas estas opciones permiten acceso público** a tu base de datos. Esto está bien para un inventario de casa entre 2 personas, pero:

⚠️ **Cualquiera con tu configuración de Firebase podría acceder a los datos**

### Para mayor seguridad en el futuro:

Si quieres **autenticación real**, podemos añadir:
- Login con Google (más simple)
- Login con Email/Password
- Reglas que solo permitan acceso a usuarios autenticados

## 🔐 Reglas con Autenticación (Para implementar después)

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

## ✅ Recomendación Actual

Para tu caso de uso (inventario compartido entre 2 personas):
- **Usa la Opción A** durante el desarrollo
- **Cambia a Opción C** cuando la app esté lista para uso continuo
- La Opción C valida que los datos tengan la estructura correcta

---

## 🛡️ Protección Adicional

### Limitar dominios permitidos:

En Firebase Console → Authentication → Settings:
- Añade solo los dominios desde donde se usará la app
- Por defecto: `localhost` y dominios de Expo

### Monitoreo:

Ve a **Firestore → Usage** para revisar:
- Número de lecturas/escrituras
- Detectar accesos inusuales
