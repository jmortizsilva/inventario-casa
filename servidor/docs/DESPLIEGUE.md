# Desplegar el servidor en el VPS

Cómo está montado `https://inventario.jmortiz.es` y cómo se actualiza. Montado
el 26 de septiembre de 2026, igual que el backend de Guárdalo.

**Aquí no hay secretos.** Los valores reales están solo en el `.env` del VPS
y en `servidor/.env` del Mac, que Git ignora.

## Dónde está cada cosa

Entrar: `ssh -p 2138 jmortiz@94.72.98.96`.

| Qué | Dónde |
|---|---|
| Código (clon de la rama `app-nativa`, por HTTPS: el repositorio es público) | `~/inventario-casa` |
| Despliegue (`docker-compose.yml` y `.env`) | `~/compose/inventario-casa` |
| Base de datos SQLite | `~/podman-volumes/inventario-casa/datos/inventario.sqlite` |

Podman sin privilegios de administrador y `podman-compose`, nunca `docker`:
la cuenta no tiene acceso al Docker del sistema, a propósito (ver
`~/DESPLIEGUE.md` en el VPS). Si el VPS se reinicia, el contenedor arranca
solo (`podman-restart.service`).

El contenedor escucha en el 8081 por dentro y se publica en el **8093**
(Guárdalo usa el 8092 y notificaciones el 8091). El cortafuegos no deja
llegar al 8093 desde fuera: solo se entra por Caddy.

**Caddy no está en esta cuenta**: lo lleva Agus. `inventario.jmortiz.es` ya
está dado de alta con proxy al 8093. Cualquier dominio o puerto nuevo, pedírselo.

`docker-compose.yml`, que solo está en el VPS:

```yaml
services:
  inventario-casa:
    build: /home/jmortiz/inventario-casa/servidor
    container_name: inventario-casa
    restart: unless-stopped
    ports:
      - "8093:8081"
    volumes:
      - /home/jmortiz/podman-volumes/inventario-casa/datos:/app/datos
    env_file:
      - ./.env
```

## Actualizar

Primero `git push` desde el Mac. Después, en el VPS:

```bash
cd ~/inventario-casa && git pull
cd ~/compose/inventario-casa && podman-compose down
podman-compose up -d --build
```

El `down` hace falta: sin él, `up` choca con que el contenedor ya existe.

Comprobar que ha entrado el código nuevo. `Using cache` en el build no basta
para saberlo; mirar que existan los ficheros o las rutas nuevas:

```bash
podman ps                                  # "Up X seconds"
podman logs --tail 20 inventario-casa
podman exec inventario-casa ls dist/cuenta
curl -s https://inventario.jmortiz.es/     # {"ok":true,"servicio":"inventario-casa"}
```

## Variables de entorno (`~/compose/inventario-casa/.env`)

Qué es cada una: `servidor/README.md`. El `.env` se copia desde el Mac con
`scp -P 2138` y se deja con permisos 600.

```
URL_PUBLICA=https://inventario.jmortiz.es
INVENTARIO_TOKEN_SECRET=...
GOOGLE_CLIENT_ID=116912735179-...apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
APPLE_CLIENT_ID=com.jmortizsilva.inventario.web
APPLE_TEAM_ID=S92QZXCW54
APPLE_KEY_ID=SKA74TT72C
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIGT...\n-----END PRIVATE KEY-----
```

- `APPLE_APP_ID` no está: vale por defecto `com.jmortiz.inventario`.
- `APPLE_PRIVATE_KEY` va en una sola línea, con `\n` donde el `.p8` tiene
  saltos, y **sin comillas**, como en Guárdalo. El `.p8` está en
  `~/.appstoreconnect/private_keys/AuthKey_SKA74TT72C.p8` del Mac. Para
  convertirlo: `awk 'BEGIN{ORS="\\n"} {print}' AuthKey_SKA74TT72C.p8`.
- `PERMITIR_LOGIN_DEV` no está, y así debe seguir: abriría una ruta que da
  sesión con solo escribir un correo.
- Si cambia solo el `.env`: `podman-compose down && podman-compose up -d`,
  sin `--build`.

## Lo que hay dado de alta fuera

| Dónde | Qué |
|---|---|
| Google Cloud, cliente OAuth web | Dirección de vuelta `https://inventario.jmortiz.es/auth/callback/google` |
| Apple, App ID `com.jmortiz.inventario` | Sign in with Apple, como App ID principal |
| Apple, Services ID `com.jmortizsilva.inventario.web` | Dominio `inventario.jmortiz.es`, vuelta `https://inventario.jmortiz.es/auth/callback/apple` |
| Apple, clave `SKA74TT72C` | Sign in with Apple, asociada al App ID |

Para saber si las credenciales sirven, sin entrar: el `client_id` de la
redirección tiene que ser el de verdad.

```bash
curl -s -o /dev/null -w "%{redirect_url}\n" \
  "https://inventario.jmortiz.es/auth/iniciar?proveedor=apple&modo=deeplink&esquema=inventariocasa&estado=prueba"
```

Eso solo dice que las variables no están vacías. Que Google o Apple las
acepten se ve entrando de verdad: se comprobó con los dos el 26 de septiembre
de 2026.

## Consultar la base de datos

Copia antes de cualquier cosa que la cambie:

```bash
cp ~/podman-volumes/inventario-casa/datos/inventario.sqlite ~/copia-inventario.sqlite
```

No hace falta `sqlite3` en el sistema: el contenedor trae `better-sqlite3`. Se
le pasa un script por la entrada estándar. Hay que poner `readonly` si solo se
va a mirar:

```bash
cat > /tmp/consulta.js <<'FIN'
const db = require('better-sqlite3')('/app/datos/inventario.sqlite', { readonly: true });
console.log(db.prepare('SELECT id, proveedor, creado_en FROM usuarios').all());
FIN
podman exec -i inventario-casa node < /tmp/consulta.js
```

## Volver atrás

```bash
cd ~/inventario-casa
git log --oneline -5
git checkout <commit-anterior>
cd ~/compose/inventario-casa && podman-compose down && podman-compose up -d --build
```

Después, `git checkout app-nativa` para que el siguiente `git pull` vuelva a
traer la rama.
