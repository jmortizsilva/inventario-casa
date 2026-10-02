# Textos de la interfaz

Textos de la versión nativa, revisados el 25 de septiembre de 2026. Entre llaves, lo que
cambia: `{producto}`, `{categoria}`, `{n}`. Los plurales se concuerdan siempre
("1 unidad", "2 unidades", "1 producto"). `{unidades}` es en lo que se cuenta
el producto, concordado con `{n}`: "1 lata", "3 latas", "2 unidades".

La columna **Antes** es el texto de la app de Expo, cuando cambia.

## Vocabulario

| Palabra | Uso |
|---|---|
| Añadir | Crear una categoría o un producto, o meter un producto en la lista. |
| Quitar | Sacar un producto de la lista de la compra. El producto sigue en el inventario. |
| Eliminar | Borrar una categoría o un producto. |
| Lista de la compra | Siempre así, completo, en títulos. "La lista" cuando el contexto ya lo dice. |
| Unidades | La cantidad. "0 unidades", nunca "cantidad: 0". |
| Unidad | En lo que se cuenta un producto, siempre en números enteros: unidad, lata, paquete, botella, brick, bote, bolsa, caja, rollo. Sustituye a "unidades" en lo que se dice del producto ("3 latas"). |
| Agotado | Producto con 0 unidades. |

## Pestañas

| Pestaña | Título de la pantalla | Antes |
|---|---|---|
| Inventario | Inventario · con hogar: Inventario - {hogar} | Inventario Casa, {hogar} |
| Compra | Lista de la compra · con hogar: Lista de la compra - {hogar} | |
| Ajustes | Ajustes · con hogar: Ajustes - {hogar} | |

Primero la pantalla, que es lo que distingue una de otra. Guion entre
espacios: VoiceOver hace una pausa y no lo nombra. Si no cabe en una línea,
el título pasa a dos; no se corta con «…». Sin conexión se usa el último
nombre conocido del hogar.

## Categorías (pestaña Inventario)

| Elemento | Texto | Antes |
|---|---|---|
| Botón de la barra | Añadir (menú: Categoría · Producto) | Añadir nueva categoría (botón flotante +) |
| Menú, Producto | Desactivado si no hay categorías | |
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
| Fila, lo que se lee | {producto}, {n} {unidades} | igual |
| Fila, si está en la lista | {producto}, {n} {unidades}, en la lista | (no se decía) |
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
| Fila, lo que se lee | {producto}, {n} {unidades}, {categoria} | {producto}, {n} unidades, urgente, añadido manualmente |
| Fila con 0 unidades | {producto}, agotado, {categoria} | |
| Fila añadida a mano | … , añadido a mano | |
| Marca visible con 0 unidades | Agotado | ¡URGENTE! |
| Acciones del rotor | Aumentar cantidad · Disminuir cantidad | igual |
| Acción del rotor (solo si se añadió a mano) | Quitar de la lista | (no existía) |
| Fila repuesta, lo que se lee | {producto}, {n} {unidades}, {categoria}, repuesto | (desaparecía) |
| Fila repuesta, a la vista | Repuesto | |
| Lista vacía, título | No falta nada | ¡Todo bien! No hay productos con pocas unidades |

La categoría se añade porque puede haber el mismo producto en dos categorías.

Lo que sale de la lista al reponerlo se queda a la vista, marcado como
repuesto, mientras no se cambie de pestaña: así se pueden seguir sumando las
unidades compradas y el foco de VoiceOver no salta. Si se vuelven a bajar las
unidades, deja de estar repuesto. El orden no cambia durante la visita.

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
| Selector, solo al crear desde el menú de Inventario | Categoría, sin valor hasta elegir. Va antes del nombre y sin teclado abierto. Guardar desactivado hasta elegir | |
| Selector, después del nombre | Se cuenta en. Opciones en plural: Unidades, Latas, Paquetes, Botellas, Bricks, Botes, Bolsas, Cajas, Rollos. Empieza en Unidades | |
| Cantidad (al crear empieza en 1) | Cantidad: {n} {unidades} | Seleccionar cantidad (rueda de 0 a 99) |
| Interruptor | Añadir a la lista cuando queden pocas | Añadir automáticamente a la lista |
| Umbral (solo si el interruptor está activo) | Cuando queden {n} {unidades} o menos | Pasar a lista de compra con {n} unidades o menos |
| Botones | Cancelar · Guardar | Cancelar · Guardar / Guardando... |

Hecho, en el teclado del nombre, cierra el teclado y no guarda: detrás va el
selector de unidad, y con el teclado abierto VoiceOver pasaba del menú de un
selector al teclado.

"Cantidad: 3 latas" no va contra "nunca «cantidad: 0»" del vocabulario: lo que
se evita es el número suelto, y aquí siempre va con su unidad.

Para VoiceOver, los dos selectores llevan etiqueta y valor por separado, para
que no se oiga dos veces. El texto de la pantalla no cambia.

| Selector | Etiqueta | Valor | Se oye |
|---|---|---|---|
| Cantidad | Cantidad | {n} {unidades} | Cantidad, 3 latas, ajustable |
| Umbral | Pasa a la lista con | {n} {unidades} o menos (1 lata o menos; 0 latas) | Pasa a la lista con, 2 latas o menos, ajustable |

Se quitan el contador de caracteres y el texto "Guardando...": guardar en el
móvil es instantáneo.

## Anuncios

Solo después de que el cambio se haya guardado.

| Cuándo | Anuncio | Antes |
|---|---|---|
| Aumentar o disminuir | {n} {unidades} | {producto}: cantidad actualizada a {n} |
| … y entra en la lista | {n} {unidades}, añadido a la lista | |
| … y sale de la lista | {n} {unidades}, fuera de la lista | {producto} eliminado de la lista de compra |
| Disminuir con 0 unidades | Ya está en 0 | (silencio) |
| Aumentar con 999 unidades | Ya está en 999 | |
| Añadir a la lista | Añadido a la lista | {producto} añadido manualmente a la lista de compra |
| Quitar de la lista | Quitado de la lista | {producto} quitado de la lista de compra manual |
| Quitar, pero sigue por pocas unidades | Sigue en la lista, quedan {n} {unidades} | |
| Producto creado | Añadido, {producto} | Producto {producto} añadido con cantidad {n}. Pasará a lista de compra con… |
| Producto editado | Guardado, {producto} | Producto actualizado: {producto}, cantidad {n}… |
| Categoría creada | Añadida, {categoria} | Categoría {categoria} creada correctamente |
| Nombre cambiado | Guardado, {categoria} | Categoría actualizada a {categoria} |
| Producto eliminado | Eliminado, {producto}. Agita para deshacer. | {producto} eliminado |
| Categoría eliminada | Eliminada, {categoria}, con {n} productos. Agita para deshacer. | Categoría {categoria} eliminada |

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
Dentro de ella, Añadir producto crea un producto. En su ficha se elige en qué
se cuenta: unidades, latas, paquetes…

**Cambiar la cantidad.** Con los botones de más y menos de cada producto, o
desde su ficha. Con VoiceOver, con las acciones Aumentar cantidad y Disminuir
cantidad del rotor.

**Lista de la compra.** Un producto entra solo en la lista cuando le queda la
cantidad que marca su ficha, o menos, y sale al reponerlo. También se puede
añadir o quitar a mano. Si no quieres que entre solo, desactiva "Añadir a la
lista cuando queden pocas" en su ficha.

**Eliminar.** Eliminar una categoría elimina también sus productos.

**Deshacer.** Si eliminas algo por error, agita el iPhone o usa Deshacer en la
barra. Se recupera lo último eliminado; si era una categoría, con sus
productos.

**Importar datos.** En Ajustes, Importar datos añade lo que trae un archivo
exportado del inventario. Las categorías con el mismo nombre se juntan, y los
productos que ya estaban no se repiten.

Después van «Compartir con tu casa» (apartado «Cuenta y hogar») y estos:

**Varios hogares.** Puedes estar en hasta 10 hogares, cada uno con su
inventario. En Ajustes, Hogares los muestra todos, y el que tienes abierto se
marca como Hogar actual. Para cambiar, entra en otro y pulsa Abrir este hogar;
con VoiceOver, también con la acción Abrir del rotor. Al crear otro hogar
puedes copiar del actual las categorías, o las categorías y los productos.

**Notificaciones.** En Ajustes, en la pantalla de cada hogar, eliges de qué te
avisa: productos y categorías nuevos, lo que entra y sale de la lista, y las
personas que se unen. Solo avisa de lo que hacen las demás personas.

**Siri.** En Ajustes, Siri, pulsa cada acción y guarda la frase que quieras
decir, por ejemplo "He comprado". Después dísela a Siri tal cual. Siri pregunta
lo que falte, y puedes contestar el producto y las unidades de una vez: "5
unidades de leche". Si no te entiende una palabra, dila de otra forma. Todo va
al hogar abierto.

## Concordancias

Casos en los que el texto cambia además del número:

| Caso | Texto |
|---|---|
| Umbral 1 | Cuando quede 1 unidad o menos |
| Umbral 0 | Cuando no quede ninguna (unidad, lata, botella, bolsa, caja) · Cuando no quede ninguno (paquete, brick, bote, rollo) |
| Sigue en la lista con 1 unidad | Sigue en la lista, queda 1 unidad |
| Sigue en la lista con 0 unidades | Sigue en la lista, agotado |
| Eliminar categoría con 1 producto | También se eliminará su producto. |
| Categoría eliminada con 1 producto | Eliminada, {categoria}, con 1 producto. Agita para deshacer. |
| Categoría eliminada sin productos | Eliminada, {categoria}. Agita para deshacer. |

## Cuenta y hogar (fase 4)

Revisados el 26 de septiembre de 2026, antes de escribir las pantallas.

Lo que está entre corchetes es para VoiceOver y no se ve. «Pista» es lo que
VoiceOver dice después de una pausa. `{correo}`, `{hogar}`, `{codigo}`,
`{fecha}` y `{n}` cambian.

### Vocabulario nuevo

| Palabra | Uso |
|---|---|
| Iniciar sesión · Cerrar sesión | Con la cuenta. El botón de Apple lo pinta iOS y dice «Iniciar sesión con Apple»: el de Google dice lo mismo para que los dos se llamen igual. |
| Hogar | El inventario compartido y las personas que lo comparten. |
| Código | El de invitación. Nunca «token» ni «clave». |
| Unirse | Entrar en el hogar de otra persona con su código. |
| Salir | Dejar el hogar. El inventario se queda en el iPhone. |
| Eliminar cuenta | Borrarla del servidor. Nunca «darse de baja». |

### Bienvenida (la primera vez que se abre la app)

Pantalla entera, sin pestañas detrás. Sale una sola vez: después, la sesión
se inicia desde Ajustes.

| Elemento | Texto |
|---|---|
| Título | Inventario Casa |
| Texto | Lleva la cuenta de lo que hay en casa y de lo que falta comprar. |
| Texto | Con cuenta, compartes el inventario con tu casa y lo tienes en varios dispositivos. Sin cuenta, la app funciona igual, pero todo se queda en este iPhone. |
| Botón (del sistema) | Iniciar sesión con Apple |
| Botón | Iniciar sesión con Google |
| Botón | Usar sin cuenta |
| Texto, debajo | Puedes iniciar sesión más tarde desde Ajustes. |

Si falla el inicio de sesión, el error sale debajo de los botones, igual que
en Ajustes, y se puede reintentar o usar sin cuenta.

### Ajustes, sin sesión

| Elemento | Texto |
|---|---|
| Encabezado de sección | Cuenta |
| Texto | Sin cuenta, el inventario se guarda solo en este iPhone. |
| Botón (del sistema) | Iniciar sesión con Apple |
| Botón | Iniciar sesión con Google |
| Pista de los dos | Para compartir el inventario con tu casa |
| Pista añadida al de Google | Se abre Safari para confirmar tu cuenta |
| Error (debajo, y se anuncia) | No se ha iniciado sesión. {causa} |

Causas: «Sin conexión.» · «El servidor no responde. Prueba más tarde.» ·
«Tu cuenta no ha dado ningún correo, y hace falta.» · «No se aceptó el inicio
de sesión. Prueba otra vez.» Las dos últimas son las que manda el servidor
cuando el proveedor no da correo o no acepta el código. Si la persona cancela
en Apple o en Safari, no se dice nada: lo ha decidido ella.

### Justo después de iniciar sesión, sin hogar

Hoja con título **Tu hogar**.

| Elemento | Texto |
|---|---|
| Texto | Un hogar es un inventario compartido. Crea el tuyo o únete al de otra persona con su código. |
| Botón | Crear hogar |
| Botón | Unirme con un código |
| Botón | Ahora no |

«Ahora no» deja la sesión iniciada sin hogar; los dos botones siguen en
Ajustes.

«Tu nombre» solo sale si la cuenta todavía no tiene nombre, que es lo que
pasa con Apple. Con Google se usa el de la cuenta, que se cambia desde
Ajustes. Crear y Unirme están desactivados mientras falte.

### Crear hogar

| Elemento | Texto |
|---|---|
| Título | Nuevo hogar |
| Campo | Nombre del hogar |
| Campo | Tu nombre |
| Pista de «Tu nombre» | Así te verán las demás personas del hogar |
| Texto, si es el primer hogar y hay algo en el iPhone | Tu inventario de este iPhone pasa al hogar: {n} categorías y {n} productos. |
| Elección, si ya hay otro hogar con algo | Copiar de {hogar}: Nada · Solo las categorías · Categorías y productos |
| Pie de la elección | {hogar} se queda como está. |
| Botones | Cancelar · Crear |
| Anuncio | Hogar creado, {hogar} |
| Anuncio, si no se pudo copiar | Hogar creado, {hogar}. No se ha podido copiar nada. |
| Error | No se ha creado el hogar. {causa} |

La copia no quita nada del hogar actual. Los productos llegan con cantidad 0
y fuera de la lista manual; conservan el mínimo y si entran solos en la lista.
Con cantidad 0, los que tienen mínimo aparecen en la lista de la compra del
hogar nuevo.

### Unirme con un código

| Elemento | Texto |
|---|---|
| Título | Unirme a un hogar |
| Campo | Código |
| Campo | Tu nombre |
| Pista de «Tu nombre» | Así te verán las demás personas del hogar |
| Texto | Pide el código a alguien del hogar. |
| Botones | Cancelar · Unirme |
| Anuncio | Unido al hogar, {hogar} |
| Código que no vale | Ese código no sirve. Puede que haya caducado o que ya se haya usado. |
| Demasiados intentos | Demasiados intentos. Prueba dentro de una hora. |
| Otro error | No te has unido. {causa} |

Si había algo en el iPhone, al unirse sale una alerta sin Cancelar: ya se ha
entrado en el hogar y las dos respuestas son definitivas.

| Título | Mensaje | Botones |
|---|---|---|
| Inventario de este iPhone | Hay {n} categorías y {n} productos en este iPhone. ¿Los añades a {hogar}? Si no, se eliminan de este iPhone. | Añadirlos · Eliminarlos |

Solo se nombra lo que no es cero («Hay 3 categorías en este iPhone»). Si solo
hay categorías, todo va en femenino: «¿Las añades…?», «Añadirlas»,
«Eliminarlas».

### Ajustes, con sesión

Desde el 28 de septiembre de 2026, con varios hogares:

| Elemento | Texto |
|---|---|
| Encabezado de sección | Hogares |
| Fila del hogar actual | {hogar} y, debajo, «Hogar actual». VoiceOver: «{hogar}, hogar actual» |
| Fila de otro hogar | {hogar} |
| Acción del rotor en las filas que no son el actual | Abrir |
| Botones, debajo de la lista | Crear hogar · Unirme con un código |
| Anuncio al cambiar de hogar | Hogar actual, {hogar} |
| Encabezado de sección | Cuenta |
| Texto | Sesión iniciada como {correo} |
| … con el correo oculto de Apple | Sesión iniciada con Apple |
| Estado | Todo enviado · {n} cambios sin enviar · Sin conexión · Sin conexión, {n} cambios sin enviar |
| Botón | Cambiar tu nombre (es de la cuenta, no de un hogar) |
| Botón | Cerrar sesión |
| Botón | Eliminar cuenta |
| Sesión caducada | La sesión ha caducado. Vuelve a iniciarla. |

Pulsar un hogar abre su pantalla, con su nombre como título. Se configura
aunque no sea el actual:

| Elemento | Texto |
|---|---|
| Botón, si no es el actual | Abrir este hogar |
| Fila | En el hogar: Ana y Luis |
| Botón | Invitar a alguien |
| Sección | Notificaciones (de ese hogar; ver «Notificaciones») |
| Botón | Salir del hogar |

Cerrar sesión envía antes lo pendiente de todos los hogares, porque los que
no son el actual se quitan del iPhone. Si algo no se pudo enviar, pregunta
como siempre, contando los cambios de todos.

Sin hogar, en lugar de la primera sección: encabezado «Hogar», texto «No estás
en ningún hogar.» y los botones «Crear hogar» y «Unirme con un código».

### Invitar

| Título | Mensaje | Botones |
|---|---|---|
| Código de invitación | {codigo}. Sirve una vez y caduca el {fecha}. | Compartir · Aceptar |

El código se muestra tal cual; quien lo necesite letra a letra lo lee con
el rotor de VoiceOver. {fecha} se escribe «3 de octubre».

Texto que se comparte, con el enlace al final de su línea para que las apps
de mensajes lo hagan pulsable:

> Únete a mi hogar en Inventario Casa: https://inventario.jmortiz.es/unirse/{codigo}
> Si no se abre la app, escribe el código {codigo} en Ajustes, Unirme con un código. Caduca el {fecha}.

### Abrir el enlace de invitación

| Situación | Qué pasa |
|---|---|
| Con sesión y sin hogar | Se abre «Unirme a un hogar» con el código escrito. Hay que pulsar Unirme |
| Sin sesión | Hoja «Unirme a un hogar» con «Para unirte a un hogar, inicia sesión.» y los botones de Apple y Google; al iniciar sesión, sigue con el código escrito |
| Ya en un hogar | Alerta «Ya estás en {hogar}», mensaje «Para unirte a otro, sal antes de este.», botón Aceptar |
| Primera vez, con la bienvenida | Primero la bienvenida; al iniciar sesión, sigue a «Unirme a un hogar» con el código |

Página web, si se abre sin la app. Dice «móvil» y no «iPhone»: servirá
también para Android.

| Elemento | Texto |
|---|---|
| Título de la pestaña | Invitación a Inventario Casa |
| Encabezado | Te han invitado a un hogar |
| Párrafo | Abre este enlace en el móvil donde tengas Inventario Casa y se abrirá la invitación. |
| Párrafo | O escribe este código en la app, en Ajustes, Unirme con un código: |
| Código, en grande | {codigo} |
| Párrafo | El código sirve una vez y caduca a los 7 días. |

### Confirmaciones

| Cuándo | Título | Mensaje | Botones |
|---|---|---|---|
| Salir del hogar | ¿Salir de {hogar}? | El inventario se queda en este iPhone, pero deja de compartirse. Para volver hará falta otro código. | Salir · Cancelar |
| … teniendo otros hogares | ¿Salir de {hogar}? | Su inventario se quita de este iPhone. Para volver hará falta otro código. | Salir · Cancelar |
| … teniendo otros, y siendo la última persona | ¿Salir de {hogar}? | Eres la única persona del hogar: se eliminará del servidor dentro de 30 días. Su inventario se quita de este iPhone. | Salir · Cancelar |
| … si es la última persona | ¿Salir de {hogar}? | Eres la única persona del hogar: se eliminará del servidor dentro de 30 días. El inventario se queda en este iPhone. | Salir · Cancelar |
| Cerrar sesión con cambios sin enviar | ¿Cerrar sesión? | Hay {n} cambios sin enviar. Si cierras sesión, se quedan solo en este iPhone. | Cerrar sesión · Cancelar |
| Eliminar cuenta | ¿Eliminar tu cuenta? | Se eliminan tu cuenta y tus datos del servidor. {hogar sigue o no}. El inventario se queda en este iPhone. | Eliminar cuenta · Cancelar |

Cerrar sesión sin cambios pendientes no pregunta. En «Eliminar cuenta», con
un hogar: «El hogar sigue para las demás personas.» o, si es la última, «El
hogar {hogar} y su inventario también se eliminan.». Con varios: «Los hogares
Casa y Playa, con su inventario, también se eliminan.» para los que son solo
suyos, y «Piso sigue para las demás personas.» / «Piso y Casa siguen para las
demás personas.» para los compartidos. Con cuenta de
Apple se añade «Para confirmarlo, Apple te pedirá que inicies sesión otra vez.
No se abre ninguna sesión nueva: es solo para poder eliminarla.», porque
después sale su hoja, que dice «iniciar sesión» y no se puede cambiar.

### Anuncios y errores

| Cuándo | Anuncio |
|---|---|
| Sesión iniciada | Sesión iniciada |
| Salir del hogar | Has salido de {hogar} |
| Nombre cambiado | Guardado, {nombre} |
| Sesión cerrada | Sesión cerrada |
| Cuenta eliminada | Cuenta eliminada |
| Error al salir | No has salido del hogar. {causa} |
| Error al invitar | No se ha creado el código. {causa} |
| Error al cambiar tu nombre | No se ha guardado el nombre. {causa} |
| Unirse a un hogar en el que ya está | Ya estás en ese hogar. |
| Crear o unirse con 10 hogares | Ya estás en 10 hogares, que es el máximo. |
| Error al eliminar la cuenta | No se ha eliminado la cuenta. {causa} |

Cerrar sesión no tiene error: si el servidor no contesta, la sesión se
cierra en el iPhone igual.

Causas propias de eliminar cuenta: «Apple no ha confirmado. Prueba otra vez.» ·
«No se pudo hablar con Apple. Prueba más tarde.»

La sincronización no anuncia nada: ni al enviar ni cuando llegan cambios de
otra persona. Con cada toque de más o menos sonaría algo. Lo que no se ha
podido enviar se ve en el estado de Ajustes.

### Manual, apartado nuevo

**Compartir con tu casa.** En Ajustes, inicia sesión y crea un hogar. Con
Invitar a alguien sale un código: quien lo escriba en Unirme con un código
comparte el inventario contigo. Los cambios llegan a todos cuando hay
conexión; sin ella, la app funciona igual y los envía después.

## Notificaciones

Revisados el 27 de septiembre de 2026. Los de las notificaciones los compone
el servidor (`servidor/src/avisos/textos.ts`), que es quien sabe qué ha
cambiado: valen igual para iOS y Android.

### Ajustes

Sección nueva, solo con sesión y hogar. Los cinco interruptores empiezan
desactivados; el primero que se active pide permiso a iOS. Si se deniega,
el interruptor vuelve a quedar desactivado y sale el aviso de abajo.

| Elemento | Texto |
|---|---|
| Encabezado | Notificaciones |
| Interruptor | Productos nuevos |
| Interruptor | Categorías nuevas |
| Interruptor | Lo que entra en la lista |
| Interruptor | Lo que sale de la lista |
| Interruptor | Personas nuevas en el hogar |
| Pie | Solo avisa de lo que hacen las demás personas del hogar. |
| Sin permiso de iOS | Las notificaciones están desactivadas para Inventario Casa en Ajustes del iPhone. |
| Botón, sin permiso | Abrir Ajustes |

### Las notificaciones

Título: el nombre del hogar. Una por tipo de cambio y por envío (la app
agrupa sus cambios dos segundos), nunca a quien hizo el cambio. Con varios,
se nombran hasta dos y el resto se cuenta.

| Cuándo | Cuerpo |
|---|---|
| Producto nuevo | Ana ha añadido Leche |
| … varios | Ana ha añadido Leche y 3 productos más |
| Categoría nueva | Ana ha añadido la categoría Limpieza |
| … varias | Ana ha añadido la categoría Limpieza y 2 más |
| Entra en la lista | A la lista: Leche |
| … varios | A la lista: Leche, Pan y 2 más |
| Sale de la lista | Fuera de la lista: Leche |
| … varios | Fuera de la lista: Leche, Pan y 2 más |
| Alguien se une | Luis se ha unido al hogar |
| … sin nombre | Alguien se ha unido al hogar |

Lo de la lista no dice quién: casi siempre entra sola, al bajar las
unidades, y «Ana ha puesto Leche en la lista» sería falso.

Concordancias: «y 1 producto más», «y 1 más»; con dos nombres y nada más,
«A la lista: Leche y Pan».

## Deshacer

Revisados el 27 de septiembre de 2026. Se deshace lo último eliminado (un
producto, o una categoría con sus productos), agitando el iPhone o con el
botón de la barra. El botón sigue hasta el siguiente cambio o hasta salir de
esa pantalla: con VoiceOver, llegar a la barra lleva su tiempo, y uno que
desaparece a los diez segundos no se llega a usar.

| Cuándo | Texto |
|---|---|
| Botón en la barra, a la izquierda | Deshacer |
| Lo que lee VoiceOver en el botón | Deshacer, eliminar {nombre} |
| Alerta de iOS al agitar | Deshacer Eliminar {nombre} (la pone iOS con el nombre de la acción) |
| Anuncio, producto | Recuperado, {producto} |
| Anuncio, categoría | Recuperada, {categoria}, con {n} productos · con 1: «con 1 producto» · sin productos: «Recuperada, {categoria}» |
| Si no se puede guardar | La alerta de siempre: «No se ha guardado» |

El anuncio al eliminar termina en «Agita para deshacer.»: sin decirlo, nadie
sabe que se puede.

## Siri

### Pantalla «Siri» en Ajustes

Revisados el 29 de septiembre de 2026. Cada fila es un solo botón; VoiceOver
lee «Crear producto, Sin frase, botón» o «Crear producto, «Nuevo producto»,
botón». Al pulsarla se abre la hoja de Apple («Añadir a Siri» o editar la
frase), con sus propios textos.

| Elemento | Texto |
|---|---|
| Fila en Ajustes | Siri |
| Título | Siri |
| Filas | Crear producto · Añadir unidades · Quitar unidades · Cambiar la cantidad · Consultar un producto · Eliminar producto |
| Debajo, sin frase | Sin frase |
| Debajo, con frase | «{frase}» |
| Frase que propone la hoja | Nuevo producto · He comprado · He gastado · Cambiar cantidad · Cuánto queda · Eliminar producto |
| Pie | Elige una frase para cada acción y díselo a Siri tal cual. |
| Botón a Atajos | Lo pone Apple: «Atajos de InventarioCasa» (toma el nombre interno; se decidió dejarlo así) |

### Preguntas de las acciones de «Añadir a Siri»

Revisadas el 30 de septiembre de 2026. Están en `Siri/Voz.intentdefinition`
(se genera con un script); las respuestas son las de `Textos.Siri`, abajo. El
producto se dice, no se elige de una lista: con lista, Siri la leía entera,
con las categorías, y preguntaba «¿Cuál?». La categoría solo se nombra si dos
productos se llaman igual («Leche, Nevera»).

| Acción | Producto | Unidades |
|---|---|---|
| Crear producto | ¿Qué producto? · ¿En qué categoría lo guardo? | ¿Cuántas unidades? |
| Añadir unidades | ¿Qué has comprado? | ¿Cuántas {unidades}? |
| Quitar unidades | ¿Qué producto? | ¿Cuántas {unidades}? |
| Cambiar la cantidad | ¿De qué producto? | ¿Cuántas {unidades} hay? |
| Consultar un producto | ¿De qué producto? | — |
| Eliminar producto | ¿Qué producto quieres eliminar? | — |
| Si encaja con varios | Hay varios: (Siri los lee) ¿Cuál de ellos? | — |

En añadir, quitar y cambiar la cantidad se puede contestar todo de una vez:
«5 unidades de leche», «2 latas de atún», «una leche». Entonces Siri no
pregunta las unidades. Si solo se dice el producto, las pregunta.

La pregunta por las unidades lleva el envase del producto y concuerda:
«¿Cuántas latas?», «¿Cuántos paquetes hay?». Crear producto sigue con
«¿Cuántas unidades?»: el producto aún no existe y por voz no se elige envase.
La definición solo admite textos fijos, así que la pregunta va en un
parámetro oculto (`pregunta`) que la app rellena después del producto, y la
de las unidades es «${pregunta}». Comprobado en el iPhone el 2 de octubre de
2026. Siri resuelve por número de parámetro: con la pregunta detrás de las
unidades decía la suya, «¿Qué valor de unidades quieres?», que no deja claro
si pide el número o el envase.

Lo que no vale se dice en el momento, con lo que se acaba de decir, y Siri
vuelve a preguntar (antes llegaba al final, después de pedir las unidades):

| Cuándo | Texto |
|---|---|
| Producto que no existe | No encuentro {lo dicho}. |
| Categoría que no existe | No encuentro la categoría {lo dicho}. |
| Encaja con varias categorías | Hay varias categorías así. Dilo con el nombre entero. |
| Ya hay un producto con ese nombre en la categoría | Ya hay un producto con ese nombre en {lo dicho}. |

Estos textos están en `Siri/Voz.intentdefinition` y no pueden nombrar el
hogar.

Siri a veces toma una respuesta por una orden («ejecuta el comando
despensa») y a la app le llega vacía; pasó con «despensa» y «fregona», no
con «cubo», «casa» ni «conservas». La segunda vez que llega vacía:

| Qué | Texto |
|---|---|
| Nombre al crear | No te he entendido. Dilo de otra forma. (y vuelve a preguntar) |
| Categoría | Estas son tus categorías: (Siri las lee) ¿En cuál lo guardo? |

La confirmación antes de eliminar la compone Siri con el título «Eliminar
{producto}»; sus palabras exactas no se pueden cambiar desde la definición.

### Frases de la app

Todas las acciones van al hogar abierto. Las frases, los títulos de las
acciones y las preguntas son literales en `InventarioCasa/Siri` (Apple los
lee al compilar); las respuestas están en `Textos.Siri`, con pruebas.

### Frases

«Inventario Casa» es el nombre de la app, que Siri exige en la frase.

| Acción (título en Atajos) | Frases |
|---|---|
| Añadir unidades | Añade {producto} en Inventario Casa · He comprado {producto} en Inventario Casa |
| Quitar unidades | Quita {producto} en Inventario Casa · He gastado {producto} en Inventario Casa |
| Cambiar la cantidad | Cambia la cantidad de {producto} en Inventario Casa |
| Crear producto | Crea un producto en Inventario Casa · Nuevo producto en Inventario Casa |
| Eliminar producto | Elimina {producto} de Inventario Casa |
| Consultar un producto | ¿Cuántas unidades de {producto} hay en Inventario Casa? · Consulta {producto} en Inventario Casa |

Pocas frases por acción: Siri acepta formas parecidas (flexible matching,
desde iOS 17), y según la guía de Apple las variantes casi iguales empeoran
el reconocimiento.

Para consultar no se usa «¿cuánta leche queda?»: la frase tendría que
concordar con cada producto y Siri no la adapta.

### Preguntas

| Cuándo | Texto |
|---|---|
| Falta el producto | ¿Qué producto? |
| Añadir o quitar | ¿Cuántas {unidades}? (¿Cuántos paquetes?) |
| Cambiar la cantidad | ¿Cuántas {unidades} hay? |
| Crear: nombre | ¿Cómo se llama? |
| Crear: categoría | ¿En qué categoría? |
| Crear: unidades | ¿Cuántas unidades? |
| Eliminar | ¿Elimino {producto} de {categoría}? |

### Respuestas

| Cuándo | Texto |
|---|---|
| Añadir, quitar o cambiar la cantidad | {producto}, {n} {unidades}. y, según la lista de la compra: Añadido a la lista de la compra. · Sigue en la lista de la compra. · Quitado de la lista de la compra. |
| Consultar | {producto}, {n} {unidades} (y «, en la lista» si está en la lista) |
| Crear | Creado, {producto} en {categoría} |
| Eliminar | Eliminado, {producto} |
| Eliminar, contestando que no | No se ha eliminado {producto} |
| No encuentra el producto o la categoría | No encuentro {lo dicho} en {hogar}. (sin hogar: No encuentro {lo dicho}.) |
| Lo dicho encaja con varias categorías | Hay varias categorías así: {nombres}. Dilo con el nombre entero. |
| Nombre repetido al crear | Ya hay un producto con ese nombre en {categoría} |

El hogar no se nombra en las respuestas, salvo cuando no se encuentra el
producto: así son cortas.

Con el iPhone bloqueado, consultar, añadir y quitar funcionan; crear y
eliminar piden desbloquearlo.
