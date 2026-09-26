# Servidor: diseño

Decisiones aprobadas el 25 de septiembre de 2026.

Sirve para dos cosas: compartir un inventario entre varias personas (un
hogar) y tenerlo igual en varios dispositivos. La app sigue funcionando sin
cuenta y sin conexión; el servidor solo hace falta para compartir.

## Decisiones

### 1. Un servicio aparte en el mismo VPS

Carpeta `servidor/` en este repositorio, contenedor propio
(`inventario-casa`), base de datos propia y un subdominio propio
(`inventario.jmortiz.es`) detrás del mismo Caddy. Se despliega igual que
Guárdalo: Podman sin privilegios de administrador y `podman-compose`.

Descartado: meter el inventario en el backend de Guárdalo. Compartirían
cuentas, pero un despliegue de uno podría romper el otro, y Guárdalo ya tiene
como norma que sus proyectos no dependan entre sí.

### 2. Las mismas herramientas que Guárdalo

Node, Fastify, SQLite y TypeScript, con pruebas en Vitest. El inicio de sesión
se copia de Guárdalo (Google por el navegador y Apple nativo en iOS, sin
contraseñas), con sus tokens de acceso cortos y de refresco con rotación. Ya
está probado en el iPhone y sus trampas están documentadas.

Descartado: Swift con Vapor. Permitiría reutilizar el núcleo de la app, pero
sería una segunda forma de montar servidores en el VPS y habría que rehacer
el inicio de sesión, que en Node ya funciona. Además, Android hablará con el
servidor por el contrato de la API y no por código compartido.

### 3. Cuenta opcional

Sin cuenta, la app funciona como ahora, solo en el móvil. La primera vez que
se abre, una pantalla ofrece iniciar sesión con Apple o con Google, o usar la
app sin cuenta; después, la sesión se inicia desde Ajustes.

Al iniciar sesión sin hogar se pregunta si crear uno, con lo que ya haya en el
móvil, o unirse al de otra persona con su invitación. Corregido el 26 de
septiembre de 2026: antes decía que lo del móvil pasaba solo a un hogar
nuevo, y quien iniciara sesión para unirse al hogar de su pareja se
encontraría con uno propio del que tendría que salir primero.

Cada persona pone su nombre al crear un hogar o unirse a uno: Apple no lo da,
y su correo puede ser una dirección oculta que no dice quién es.

### 4. Hogares, miembros e invitaciones

- **Un hogar por persona** en esta primera versión. La app de Expo permitía
  varios, pero complica la app (qué se ve, dónde se guarda lo nuevo) sin que
  haga falta todavía.
- **La pertenencia la decide el servidor** en cada petición, mirando su propia
  tabla de miembros. Nunca se fía de lo que diga el móvil: ese era el agujero
  de las reglas de Firestore.
- **Invitaciones:** código de 8 caracteres sin letras que se confundan (sin
  0/O ni 1/I), válido 7 días y para un solo uso, y con límite de intentos
  para que no se pueda probar códigos a ciegas. Lo crea cualquier miembro.
- **Unirse a un hogar** con cosas ya guardadas en el móvil: se pregunta si se
  añaden al hogar o se descartan, igual que hace Guárdalo al entrar.
- **Salir del hogar:** se queda la copia local; el hogar sigue para los demás.
  Si sale la última persona, el hogar se borra a los 30 días.

### 5. Sincronización

La misma idea que Guárdalo (identificadores generados en el móvil, borrado
lógico, envío y recepción por lotes), con dos diferencias:

- **Las novedades se piden por número de revisión del servidor, no por
  hora.** Cada cambio aceptado recibe el siguiente número del hogar, y cada
  móvil pide «lo que haya después de la revisión N». Así un reloj atrasado no
  hace que se pierdan cambios. La hora del móvil (`modificado`) solo decide
  qué versión gana cuando dos personas cambian el mismo campo.
- **Las unidades se sincronizan como sumas y restas, no como valor final.**
  Cada toque de más o menos es un movimiento con su propio identificador
  (`+1`, `-1`), y el servidor los suma. Si dos personas restan a la vez, se
  restan las dos veces; con «gana el último», una se perdería. Fijar las
  unidades desde la ficha sí es un valor final. El núcleo ya separa las dos
  operaciones (`ajustarCantidad` y `fijarCantidad`).

Consecuencia a aceptar: si dos personas crean «Leche» en la misma categoría
sin conexión, aparecen las dos. El servidor no fusiona nada por su cuenta; se
ve y se elimina una.

### 6. Datos de Firestore

No hace falta código en el servidor. Tu hogar ya se puede importar en la app
(Ajustes → Importar datos); al entrar con la cuenta, sube como hogar nuevo.
Los hogares de otras personas no se pasan salvo que lo pidan.

### 7. Borrar la cuenta

Decidido el 26 de septiembre de 2026. Apple lo exige para publicar una app
que permite crear cuentas.

- **Se borra de verdad** lo personal: correo, nombre, identificador del
  proveedor y sesiones. Descartado marcarla como inactiva (`activo = 0`):
  guardar el correo de quien se ha ido no sirve para nada.
- **El inventario es del hogar**: si quedan otros miembros, sigue con ellos.
  Si era la única persona, el hogar se borra en el acto. Los 30 días de
  «salir» tienen sentido porque la cuenta sigue y se puede volver; aquí ya no
  queda nadie que pueda entrar.
- **Apple exige revocar el acceso** con su API. La app pide identificarse
  otra vez con Apple y manda el código; el servidor lo canjea y revoca.
  Descartado guardar el token de refresco de Apple desde el primer inicio de
  sesión: sería un secreto de Apple por persona guardado todo el tiempo para
  usarlo una vez.
- **Avisos de Apple** (`POST /auth/apple/avisos`): si la persona borra su
  cuenta de Apple, se borra la de aquí; si quita la app de su Apple ID, se
  cierran sus sesiones.

## Contrato de la API (borrador)

Mismo estilo que el de Guárdalo: sin versión en la ruta, cambios solo
aditivos, `Authorization: Bearer` en todo lo que no es `/auth/`. Irá entero en
`servidor/docs/CONTRATO-API.md` antes de escribir código.

| Ruta | Para qué |
|---|---|
| `/auth/…` | Igual que Guárdalo: iniciar, callback, canjear, renovar, cerrar sesión, Apple nativo |
| `GET /hogar` | Mi hogar y sus miembros (o ninguno) |
| `POST /hogar` | Crear el mío (al entrar por primera vez) |
| `POST /hogar/invitaciones` | Crear un código |
| `POST /hogar/unirse` | Unirse con un código |
| `POST /hogar/salir` | Salir |
| `GET /sincronizar?desde=<revisión>` | Categorías, productos y unidades cambiados después de esa revisión |
| `POST /sincronizar` | Cambios del móvil: categorías, productos y movimientos de unidades |
| `PUT /cuenta/nombre` | El nombre con el que te ven en el hogar |
| `DELETE /cuenta` | Borrar la cuenta |
| `POST /auth/apple/avisos` | Avisos de Apple: cuenta borrada o app quitada del Apple ID |

## Fases

1. **Servidor en local:** inicio de sesión, hogares e invitaciones, con
   pruebas. Sin tocar el VPS.
2. **Sincronización en el servidor**, con pruebas y con casos en JSON que
   usen también las apps (como `casos-lista-compra.json`).
3. **Despliegue en el VPS.** Hecho el 26 de septiembre de 2026: ver
   [`servidor/docs/DESPLIEGUE.md`](../servidor/docs/DESPLIEGUE.md).
4. **App:** entrar, hogar e invitaciones, y sincronización. Los textos, antes,
   para revisarlos.
5. **Android**, más adelante, contra el mismo contrato.

## Aprobado

Servicio aparte en el mismo VPS, Node como Guárdalo, un hogar por persona
para empezar, subdominio `inventario.jmortiz.es` e inicio de sesión con
Google y con Apple.
