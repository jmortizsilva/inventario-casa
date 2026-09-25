# Contrato de API — servidor de Inventario Casa

Fuente de la verdad entre el servidor (`servidor/`) y las apps (iOS ahora,
Android después), que no comparten código. Cualquier cambio se decide aquí
primero. El porqué de cada decisión está en [`docs/SERVIDOR.md`](../../docs/SERVIDOR.md).

Base: `${URL_PUBLICA}` (`https://inventario.jmortiz.es`). Sin prefijo de
versión: los cambios tienen que ser aditivos.

Salvo las rutas bajo `/auth/`, todas exigen `Authorization: Bearer
<tokenAcceso>`. Sin él, o con uno caducado o no válido: `401 {"error": "..."}`.

Fechas: milisegundos desde 1970 (enteros). Identificadores de categorías,
productos y movimientos: UUID generados en el móvil.

---

## Autenticación

**Igual que Guárdalo** (`backend/docs/CONTRATO-API.md` de Guardar Enlaces),
con estas diferencias:

| Qué | Aquí |
|---|---|
| Esquema del enlace de vuelta | `inventariocasa` |
| Modos de `/auth/iniciar` | Solo `deeplink`. No hay cliente de Windows, así que no hay `polling` ni `/auth/estado` |
| `aud` que se comprueba en `/auth/apple-nativo` | `com.jmortiz.inventario` |
| Datos del usuario en las respuestas | `{ "id", "email", "nombre", "proveedor" }`; `nombre` es el que da el proveedor, o `null` |

Rutas: `GET /auth/iniciar`, `GET|POST /auth/callback/:proveedor`,
`POST /auth/canjear`, `POST /auth/renovar`, `POST /auth/logout`,
`POST /auth/logout-todas`, `POST /auth/apple-nativo`,
`POST /auth/apple/avisos` y, solo con `PERMITIR_LOGIN_DEV=true`,
`POST /auth/dev-login`.

La identidad es el par (proveedor, `sub`), nunca el correo. El alta es
abierta: entrar la primera vez crea la cuenta, sin hogar.

Un token de acceso de una cuenta que ya no existe da `401`, aunque no haya
caducado.

### `POST /auth/apple/avisos`

La llama Apple, no las apps: es la dirección que va en *Server-to-Server
Notification Endpoint* del App ID. El cuerpo es `{ "payload": "<JWT>" }`,
firmado por Apple con las mismas claves que el token de inicio de sesión. Se
comprueban la firma, el emisor y que `aud` sea la app de iOS. Su campo
`events` es un JSON en texto con `type` y `sub`:

| `type` | Qué hace |
|---|---|
| `account-delete` | Borra la cuenta, como `DELETE /cuenta` pero sin revocar nada en Apple |
| `consent-revoked` | Cierra todas sus sesiones. La cuenta sigue |
| `email-disabled`, `email-enabled` | Nada: el servidor no manda correos |

→ `200 {"ok": true}`, también si el `sub` no tiene cuenta aquí. `400` si el
token no es válido.

---

## Cuenta

### `DELETE /cuenta`

Borra la cuenta: correo, nombre, identificador del proveedor y sesiones.

- Si quedan otros miembros en su hogar, el hogar y el inventario siguen con
  ellos. El inventario no guarda quién hizo cada cambio.
- Si era la única persona del hogar, el hogar y su inventario se borran en el
  acto, sin los 30 días de `POST /hogar/salir`.
- Se borran las invitaciones que creó.

**Cuentas de Apple:** Apple exige revocar el acceso al borrar la cuenta. La
app pide a la persona que se identifique otra vez con Apple (sirve también de
confirmación) y manda el `authorizationCode` que recibe:

```json
{ "codigoApple": "c1a2b3…" }
```

El servidor lo canjea con el identificador de la app de iOS y revoca el token
en Apple **antes** de borrar nada. Las cuentas de Google mandan `{}` o nada.
Ojo: con `Content-Type: application/json` y el cuerpo vacío, Fastify responde
`400` antes de llegar a la ruta.

→ `200 {"ok": true}`.

- `400 {"error": "falta_codigo_apple"}` si la cuenta es de Apple y no viene el
  código.
- `400 {"error": "codigo_apple_no_valido"}` si Apple no acepta el código (dura
  5 minutos y sirve una vez). No se borra nada: la app puede pedir otro.
- `502` si no se pudo hablar con Apple. Tampoco se borra nada.

---

## Hogar

Una persona está como mucho en un hogar. **La pertenencia la decide el
servidor** con su tabla de miembros en cada petición; el móvil nunca dice a
qué hogar pertenece.

Modelo:

```json
{
  "id": "…",
  "nombre": "Casa",
  "miembros": [ { "id": 1, "nombre": "Ana", "email": "ana@ejemplo.com" } ],
  "revision": 128
}
```

### `GET /hogar`

→ `200 { "hogar": <hogar> }`, o `200 { "hogar": null }` si no está en ninguno.

### `POST /hogar`

```json
{ "nombre": "Casa" }
```

→ `201 { "hogar": <hogar> }`. `409` si ya está en uno. `400` si el nombre está
vacío o pasa de 100 letras.

### `POST /hogar/invitaciones`

→ `201 { "codigo": "K7PX3MQA", "caducaEn": 1735689600000 }`.

Ocho caracteres de `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (sin 0/O ni 1/I/L), válido
7 días y un solo uso. Lo puede crear cualquier miembro. `409` si no está en un
hogar.

### `POST /hogar/unirse`

```json
{ "codigo": "K7PX3MQA" }
```

→ `200 { "hogar": <hogar> }`.

- `404` si el código no existe, caducó o ya se usó. **La misma respuesta para
  los tres**, para no dar pistas a quien pruebe códigos.
- `409` si ya está en un hogar: hay que salir antes.
- `429` pasados 10 intentos fallidos en una hora.

### `POST /hogar/salir`

→ `200 {"ok": true}`. El hogar sigue para los demás. Si no queda nadie, se
borra a los 30 días.

---

## Sincronización

Modelos. `cantidad` solo viene del servidor: el móvil la cambia con
movimientos o fijándola (ver abajo).

```json
// Categoría
{ "id": "…", "nombre": "Despensa", "creado": 1735000000000, "modificado": 1735600000000, "borrado": false }

// Producto
{
  "id": "…", "categoriaId": "…", "nombre": "Arroz",
  "cantidad": 3, "umbralCompra": 2, "autoListaCompra": true, "enListaCompraManual": false,
  "creado": 1735000000000, "modificado": 1735600000000, "borrado": false
}
```

### Revisión

Cada cambio que el servidor acepta en un hogar recibe el siguiente número de
**revisión** de ese hogar. Las novedades se piden por revisión y no por hora:
la hora del móvil puede ir atrasada, y entonces sus cambios quedarían por
detrás de lo que los demás ya han pedido y no los vería nadie.

La hora del móvil (`modificado`) solo sirve para decidir **qué versión gana**
cuando dos personas cambian lo mismo: gana la más reciente, por registro
entero. Si una persona cambia el nombre y otra el umbral a la vez, se queda
uno de los dos cambios. Se acepta en esta versión.

### Unidades

Dos operaciones, como en la app:

- **Movimiento** (botones de más y menos): `{ "id", "productoId", "cambio": -1, "momento" }`.
  Se guardan todos y se suman. Si dos personas restan a la vez, se restan las
  dos veces. El `id` hace que reenviar el mismo movimiento no cuente doble.
- **Fijar** (desde la ficha): el producto se envía con `cantidad` y
  `cantidadFijadaEn`. Sustituye al valor anterior.

El servidor calcula: `cantidad = última fijada + suma de los movimientos con
momento posterior a esa fijación`, acotada a 0–999 al final. El resultado no
depende del orden en que lleguen los cambios. Casos en
[`pruebas-compartidas/cantidad.json`](../../pruebas-compartidas/cantidad.json),
que usan las pruebas del servidor y tendrán que usar las de las apps.

La cantidad fijada va por su propia hora (`cantidadFijadaEn`): entra aunque el
resto del producto pierda el conflicto. Un producto nuevo sin cantidad empieza
en 0.

### `GET /sincronizar?desde=<revision>&limite=<n>`

`desde=0` trae todo el hogar. `limite` por defecto 500, máximo 1000, contando
categorías y productos juntos.

```json
{ "categorias": [ … ], "productos": [ … ], "revision": 131, "masDisponible": false }
```

Si `masDisponible` es `true`, repetir con `desde = revision`. `409` si no está
en un hogar; `400` si `desde` o `limite` no son enteros positivos.

### `POST /sincronizar`

Máximo 1000 entradas en total; con más, `413` y no se aplica nada.

```json
{
  "categorias": [ <categoría> ],
  "productos": [ <producto sin cantidad, o con cantidad y cantidadFijadaEn> ],
  "movimientos": [ { "id": "…", "productoId": "…", "cambio": 1, "momento": 1735600000000 } ]
}
```

Cada categoría y producto es alta, edición o baja (`borrado: true`), en la
misma operación. Se aplican en ese orden: categorías, productos y
movimientos, así que un producto nuevo puede venir en el mismo lote que su
categoría.

→ `200`:

```json
{
  "categorias": [ /* versión definitiva de cada una */ ],
  "productos": [ /* versión definitiva, con la cantidad calculada */ ],
  "rechazados": [ { "tipo": "producto", "id": "…", "motivo": "no_valido" } ],
  "revision": 131
}
```

El móvil sustituye lo suyo por las versiones que devuelve el servidor: pueden
no ser las que mandó si perdió un conflicto. Lo rechazado se saca igualmente
de la cola de pendientes, porque no se va a aceptar por mucho que se reenvíe.

Motivos:

- `no_valido`: nombre vacío o de más de 100 letras, umbral fuera de 0–20,
  cambio fuera de −999…999.
- `sin_categoria`: producto cuya categoría no existe en el hogar.
- `no_aplicable`: el `id` pertenece a otro hogar. No se detalla más, para no
  confirmar que existe.

**Borrar una categoría borra sus productos** en el servidor, también los que
lleguen después a esa categoría (se aceptan y se devuelven ya borrados). Así
nadie se queda con productos sueltos de una categoría que otra persona
eliminó.

Nombres repetidos: el servidor no fusiona nada. Si dos personas crean
«Leche» en la misma categoría sin conexión, quedan las dos.

`409` si no está en un hogar.
