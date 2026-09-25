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

Sin cuenta, la app funciona como ahora, solo en el móvil. Al entrar por
primera vez, lo que ya haya en el móvil pasa a ser un hogar nuevo en el
servidor. Para unirse al hogar de otra persona hace falta su invitación.

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

## Fases

1. **Servidor en local:** inicio de sesión, hogares e invitaciones, con
   pruebas. Sin tocar el VPS.
2. **Sincronización en el servidor**, con pruebas y con casos en JSON que
   usen también las apps (como `casos-lista-compra.json`).
3. **Despliegue en el VPS.** Hace falta acceso SSH, el subdominio en Caddy,
   la dirección de vuelta en Google Cloud y activar Sign in with Apple para
   `com.jmortiz.inventario`.
4. **App:** entrar, hogar e invitaciones, y sincronización. Los textos, antes,
   para revisarlos.
5. **Android**, más adelante, contra el mismo contrato.

## Aprobado

Servicio aparte en el mismo VPS, Node como Guárdalo, un hogar por persona
para empezar, subdominio `inventario.jmortiz.es` e inicio de sesión con
Google y con Apple.
