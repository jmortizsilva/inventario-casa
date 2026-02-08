# 🛒 Configuración de la Lista de la Compra

## Índice de Firebase Requerido

La funcionalidad de Lista de la Compra requiere un índice compuesto en Firebase Firestore para consultar productos con pocas unidades.

### Pasos para crear el índice:

1. **Opción A - Automático (Recomendado):**
   - Abre la app en tu iPhone
   - Ve a la pestaña "Lista de Compra"
   - Verás un error en los logs de Expo
   - El error incluirá un **link directo** para crear el índice
   - Haz clic en el link o cópialo al navegador
   - Clic en "Crear índice" en Firebase Console
   - Espera 1-2 minutos a que se complete

2. **Opción B - Manual:**
   - Ve a Firebase Console: https://console.firebase.google.com/
   - Selecciona tu proyecto: `inventario-casa-816a4`
   - Ve a "Firestore Database" → "Índices"
   - Clic en "Crear índice"
   - Configuración:
     - **Colección:** productos
     - **Campos a indexar:**
       - `cantidad` - Ascending
       - `nombre` - Ascending
     - **Ámbito de la consulta:** Collection
   - Clic en "Crear"

### ¿Por qué se necesita?

Firebase requiere un índice compuesto para consultas que:
- Usan operadores de comparación (`<=`, `>=`, `<`, `>`)
- Ordenan por múltiples campos

La lista de compra utiliza: `where('cantidad', '<=', 2).orderBy('cantidad').orderBy('nombre')`

### Tiempo de creación

- Normalmente: **1-2 minutos**
- Si tienes muchos productos: hasta 5 minutos

### ¿Cómo saber si está listo?

1. En Firebase Console → Firestore → Índices
2. El estado debe ser "Habilitado" (verde)
3. Recarga la app y la pestaña "Lista de Compra" funcionará

---

## Funcionamiento de la Lista de Compra

### Reglas automáticas:

- ✅ **Aparecen automáticamente:** Productos con 2 unidades o menos
- ✅ **Desaparecen automáticamente:** Cuando superan 2 unidades
- ✅ **Productos urgentes:** Los que tienen 0 unidades se marcan en rojo con "¡URGENTE!"
- ✅ **Sincronización:** Actualiza en tiempo real en todos los dispositivos

### Acciones disponibles:

- **Incrementar (+):** Aumenta cantidad del producto
- **Decrementar (-):** Disminuye cantidad del producto
- **Rotor de VoiceOver:**
  - Deslizar arriba: +1
  - Deslizar abajo: -1

### Visualización:

- **Ordenado por urgencia:** Primero los de 0 unidades, luego 1, luego 2
- **Dentro de cada nivel:** Ordenado alfabéticamente
- **Contador:** Muestra cuántos productos necesitas comprar

---

## Troubleshooting

### "No puedo acceder a la pestaña"
**Causa:** Falta el índice de Firebase
**Solución:** Sigue los pasos anteriores para crear el índice

### "La lista está vacía"
**Causa:** No hay productos con 2 unidades o menos
**Solución:** 
1. Ve a cualquier categoría
2. Edita un producto y ponle 2 o menos unidades
3. Vuelve a la pestaña "Lista de Compra"
4. El producto aparecerá automáticamente

### "Los productos no desaparecen"
**Causa:** El índice no está funcionando correctamente
**Solución:**
1. Verifica en Firebase Console que el índice esté "Habilitado"
2. Recarga la app completamente (cierra y abre Expo Go)

### "Error: Component auth has not been registered yet"
**Causa:** No relacionado con la lista de compra, es de autenticación eliminada
**Solución:** Solo reinicia Expo con `npx expo start --clear`

---

## Notas

- La lista de compra **NO modifica** los productos originales
- Simplemente muestra una **vista filtrada** de productos con pocas unidades
- Puedes incrementar/decrementar cantidades directamente desde la lista
- Los cambios se reflejan **inmediatamente** en el inventario principal
