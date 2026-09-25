# Textos de la interfaz

Textos de la versión nativa, revisados el 25 de septiembre de 2026. Entre llaves, lo que
cambia: `{producto}`, `{categoria}`, `{n}`. Los plurales se concuerdan siempre
("1 unidad", "2 unidades", "1 producto").

La columna **Antes** es el texto de la app de Expo, cuando cambia.

## Vocabulario

| Palabra | Uso |
|---|---|
| Añadir | Crear una categoría o un producto, o meter un producto en la lista. |
| Quitar | Sacar un producto de la lista de la compra. El producto sigue en el inventario. |
| Eliminar | Borrar una categoría o un producto. |
| Lista de la compra | Siempre así, completo, en títulos. "La lista" cuando el contexto ya lo dice. |
| Unidades | La cantidad. "0 unidades", nunca "cantidad: 0". |
| Agotado | Producto con 0 unidades. |

## Pestañas

| Pestaña | Título de la pantalla | Antes |
|---|---|---|
| Inventario | Inventario | Inventario Casa, {hogar} |
| Compra | Lista de la compra | |
| Ajustes | Ajustes | |

## Categorías (pestaña Inventario)

| Elemento | Texto | Antes |
|---|---|---|
| Botón de la barra | Añadir categoría | Añadir nueva categoría (botón flotante +) |
| Fila, lo que se lee | {categoria}, {n} productos | {categoria} |
| Acción por defecto | Abre sus productos | |
| Acción del rotor | Añadir producto | Añadir producto a {categoria} |
| Acción del rotor | Cambiar nombre | Editar categoría |
| Acción del rotor | Eliminar | Eliminar categoría |
| Sin categorías, título | No hay categorías | No hay categorías. Añade una categoría nueva con el botón más |
| Sin categorías, botón | Añadir categoría | |

## Productos de una categoría

| Elemento | Texto | Antes |
|---|---|---|
| Título | {categoria} | |
| Botón de la barra | Añadir producto | Añadir nuevo producto (botón flotante +) |
| Fila, lo que se lee | {producto}, {n} unidades | igual |
| Fila, si está en la lista | {producto}, {n} unidades, en la lista | (no se decía) |
| Acción por defecto | Abre la edición | |
| Acciones del rotor | Aumentar cantidad · Disminuir cantidad | igual |
| Acción del rotor | Añadir a la lista · Quitar de la lista | Lista de compra: añadir · Lista de compra: quitar |
| Acción del rotor | Eliminar | Eliminar producto |
| Sin productos, título | No hay productos en {categoria} | No hay productos en esta categoría. Añade uno con el botón + |
| Sin productos, botón | Añadir producto | |

Se quita la acción "Editar producto": es la misma que la acción por defecto.

## Lista de la compra

| Elemento | Texto | Antes |
|---|---|---|
| Cabecera | {n} productos | {n} productos para comprar |
| Fila, lo que se lee | {producto}, {n} unidades, {categoria} | {producto}, {n} unidades, urgente, añadido manualmente |
| Fila con 0 unidades | {producto}, agotado, {categoria} | |
| Fila añadida a mano | … , añadido a mano | |
| Marca visible con 0 unidades | Agotado | ¡URGENTE! |
| Acciones del rotor | Aumentar cantidad · Disminuir cantidad | igual |
| Acción del rotor (solo si se añadió a mano) | Quitar de la lista | (no existía) |
| Lista vacía, título | No falta nada | ¡Todo bien! No hay productos con pocas unidades |

La categoría se añade porque puede haber el mismo producto en dos categorías.

## Formulario de categoría

| Elemento | Texto | Antes |
|---|---|---|
| Título al crear | Nueva categoría | Nueva Categoría |
| Título al cambiar el nombre | Cambiar nombre | Editar Categoría |
| Campo | Nombre | Nombre de la categoría (con ejemplo "Ej: Despensa, Refrigerador...") |
| Botones | Cancelar · Guardar | Cancelar · Guardar / Guardando... |

## Formulario de producto

| Elemento | Texto | Antes |
|---|---|---|
| Título al crear | Nuevo producto | Nuevo en {categoria} |
| Título al editar | {producto} | Editar {producto} |
| Campo | Nombre | Nombre del producto (con ejemplo "Ej: Arroz, Leche, Pan...") |
| Cantidad | Unidades: {n} | Seleccionar cantidad (rueda de 0 a 99) |
| Interruptor | Añadir a la lista cuando queden pocas | Añadir automáticamente a la lista |
| Umbral (solo si el interruptor está activo) | Cuando queden {n} unidades o menos | Pasar a lista de compra con {n} unidades o menos |
| Botones | Cancelar · Guardar | Cancelar · Guardar / Guardando... |

Para VoiceOver, los dos selectores llevan etiqueta y valor por separado, para
que el número no se oiga dos veces. El texto de la pantalla no cambia.

| Selector | Etiqueta | Valor | Se oye |
|---|---|---|---|
| Unidades | Unidades | {n} | Unidades, 3, ajustable |
| Umbral | Pasa a la lista con | {n} unidades o menos (1 unidad o menos; 0 unidades) | Pasa a la lista con, 2 unidades o menos, ajustable |

Se quitan el contador de caracteres y el texto "Guardando...": guardar en el
móvil es instantáneo.

## Anuncios

Solo después de que el cambio se haya guardado.

| Cuándo | Anuncio | Antes |
|---|---|---|
| Aumentar o disminuir | {n} unidades | {producto}: cantidad actualizada a {n} |
| … y entra en la lista | {n} unidades, añadido a la lista | |
| … y sale de la lista | {n} unidades, fuera de la lista | {producto} eliminado de la lista de compra |
| Disminuir con 0 unidades | Ya está en 0 | (silencio) |
| Aumentar con 999 unidades | Ya está en 999 | |
| Añadir a la lista | Añadido a la lista | {producto} añadido manualmente a la lista de compra |
| Quitar de la lista | Quitado de la lista | {producto} quitado de la lista de compra manual |
| Quitar, pero sigue por pocas unidades | Sigue en la lista, quedan {n} unidades | |
| Producto creado | Añadido, {producto} | Producto {producto} añadido con cantidad {n}. Pasará a lista de compra con… |
| Producto editado | Guardado, {producto} | Producto actualizado: {producto}, cantidad {n}… |
| Categoría creada | Añadida, {categoria} | Categoría {categoria} creada correctamente |
| Nombre cambiado | Guardado, {categoria} | Categoría actualizada a {categoria} |
| Producto eliminado | Eliminado, {producto} | {producto} eliminado |
| Categoría eliminada | Eliminada, {categoria}, con {n} productos | Categoría {categoria} eliminada |

Se quitan "Categorías actualizadas. {n} categorías disponibles" y "Lista de
compra actualizada…", que sonaban con cada cambio de datos.

## Confirmaciones

| Cuándo | Título | Mensaje | Botones |
|---|---|---|---|
| Eliminar producto | ¿Eliminar {producto}? | | Eliminar · Cancelar |
| Eliminar categoría vacía | ¿Eliminar {categoria}? | | Eliminar · Cancelar |
| Eliminar categoría con productos | ¿Eliminar {categoria}? | También se eliminarán sus {n} productos. | Eliminar · Cancelar |

Antes: título "Confirmar eliminación", mensaje `¿Eliminar "{producto}"?`.

## Errores

Los del nombre salen debajo del campo y se anuncian. Guardar está desactivado
mientras el nombre está vacío, así que ese error no hace falta.

| Cuándo | Texto |
|---|---|
| Nombre repetido (categoría) | Ya hay una categoría con ese nombre |
| Nombre repetido (producto) | Ya hay un producto con ese nombre en {categoria} |
| Nombre demasiado largo | Máximo 100 letras |
| Fallo al guardar (alerta) | Título: No se ha guardado · Mensaje: No se pudo escribir en el móvil. Todo sigue como estaba. · Botón: Aceptar |
| Fallo al abrir la app | No se pudo leer el inventario · Botón: Reintentar |

## Ajustes

Sin servidor no quedan hogar, código, compartir ni cerrar sesión. La
importación de datos antiguos llega en la fase 6.

| Elemento | Texto |
|---|---|
| Botón | Importar datos |
| Botón | Manual |
| Versión | Versión {versión} |

## Importar datos

El resultado sale en una alerta con Aceptar, no en un anuncio: un anuncio se
puede perder y aquí importa saber qué no se importó. Título y mensaje:

| Cuándo | Título | Mensaje |
|---|---|---|
| Se importó algo | Importadas 5 categorías y 42 productos | |
| … con repetidos | Importadas 5 categorías y 40 productos | 2 ya estaban. |
| … con datos no válidos | Importados 3 productos | 1 no se pudo importar. |
| Nada nuevo | No había nada nuevo que importar | 4 ya estaban. |
| Archivo no válido | No se ha importado | El archivo no es una exportación del inventario. |
| Fallo al guardar | No se ha importado | No se pudo escribir en el móvil. Todo sigue como estaba. |

El participio concuerda con lo primero que se nombra: Importada 1 categoría,
Importadas 2 categorías, Importado 1 producto, Importados 3 productos. "No se
pudo importar" cuenta nombres vacíos o de más de 100 letras y productos sin
categoría.

## Manual

Pantalla con título "Manual" y botón "Cerrar". Cada apartado es un encabezado,
para saltar entre ellos con el rotor.

**Categorías y productos.** En Inventario, Añadir categoría crea una categoría.
Dentro de ella, Añadir producto crea un producto con sus unidades.

**Cambiar las unidades.** Con los botones de más y menos de cada producto, o
desde su ficha. Con VoiceOver, con las acciones Aumentar cantidad y Disminuir
cantidad del rotor.

**Lista de la compra.** Un producto entra solo en la lista cuando le quedan las
unidades que marca su ficha, o menos, y sale al reponerlo. También se puede
añadir o quitar a mano. Si no quieres que entre solo, desactiva "Añadir a la
lista cuando queden pocas" en su ficha.

**Eliminar.** Eliminar una categoría elimina también sus productos.

## Concordancias

Casos en los que el texto cambia además del número:

| Caso | Texto |
|---|---|
| Umbral 1 | Cuando quede 1 unidad o menos |
| Umbral 0 | Cuando no quede ninguna |
| Sigue en la lista con 1 unidad | Sigue en la lista, queda 1 unidad |
| Sigue en la lista con 0 unidades | Sigue en la lista, agotado |
| Eliminar categoría con 1 producto | También se eliminará su producto. |
| Categoría eliminada con 1 producto | Eliminada, {categoria}, con 1 producto |
| Categoría eliminada sin productos | Eliminada, {categoria} |
