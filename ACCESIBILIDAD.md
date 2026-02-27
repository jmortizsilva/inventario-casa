# Notas sobre Accesibilidad VoiceOver

## Características Implementadas

### 1. Acciones del Rotor
Cada producto tiene acciones personalizadas accesibles desde el rotor de accesibilidad:
- `increment` - Deslizar arriba para incrementar cantidad
- `decrement` - Deslizar abajo para decrementar cantidad  
- `longpress` - Editar producto (también vía acción del rotor)
- `magicTap` - Eliminar producto

### 2. Anuncios Automáticos
La app anuncia cambios importantes:
- "Categorías actualizadas. X categorías disponibles"
- "Arroz: cantidad actualizada a 5"
- "Producto Leche añadido con cantidad 2"
- "Categoría Despensa eliminada"

### 3. Labels y Hints
Todos los elementos interactivos tienen:
- `accessibilityLabel` - Descripción del elemento
- `accessibilityHint` - Qué hace cuando lo activas
- `accessibilityRole` - Tipo de elemento (button, text, header)

### 4. Focus Management
- Auto-focus en campos de texto al abrir formularios
- Selección automática de texto al editar
- Retorno de foco después de cerrar modales

### 5. Estructura Semántica
- Headers correctamente marcados con `accessibilityRole="header"`
- Listas con labels descriptivos
- Estados de botones (`accessibilityState={{ disabled: true }}`)

## Pruebas Recomendadas

1. **Activar VoiceOver:** Ajustes > Accesibilidad > VoiceOver
2. **Atajos útiles:**
   - Triple clic en botón lateral = Toggle VoiceOver
   - Rotor = Girar dos dedos en la pantalla
   
3. **Probar navegación:**
   - ✅ Navegar entre categorías con deslizar derecha/izquierda
   - ✅ Entrar a una categoría con doble tap
   - ✅ En productos, usar rotor para acciones personalizadas
   - ✅ Deslizar arriba/abajo para cambiar cantidades
   - ✅ Formularios navegables con Tab

## Guías de Apple Seguidas

- [Accessibility Programming Guide for iOS](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/iPhoneAccessibility/)
- Tamaño mínimo de toque: 44x44 pts (implementado: 50-60pts)
- Contraste de colores: WCAG AA cumplido
- Labels descriptivos sin redundancia

## Mejoras Futuras

- [ ] Soporte para texto dinámico (Dynamic Type)
- [ ] Modo oscuro con contraste aumentado
- [ ] Sonidos hápticos al cambiar cantidades
- [ ] Reducción de movimiento (reduce motion)


## Actualización de accesibilidad (feb 2026)

### Rotor

- Se unifica terminología en toda la app:
  - Aumentar cantidad
  - Disminuir cantidad
- Se elimina el uso mixto de “incrementar/decrementar”.

### Pestañas

- La barra inferior usa control de pestañas nativo (no simulado con botones).
- Implementación con `react-native-bottom-tabs` y `@bottom-tabs/react-navigation`.

### Idioma

- Se configura iOS para español en `app.json` (`CFBundleDevelopmentRegion` y `CFBundleLocalizations`).
- Nota: algunos términos del sistema dependen de VoiceOver/iOS y no de etiquetas JS.