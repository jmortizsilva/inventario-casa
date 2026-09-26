# Servidor de Inventario Casa

Cuentas, hogares compartidos y sincronización. Node + Fastify + SQLite, con
contenedor y base de datos propios. Diseño en [`docs/SERVIDOR.md`](../docs/SERVIDOR.md);
contrato de la API en [`docs/CONTRATO-API.md`](docs/CONTRATO-API.md); despliegue en
[`docs/DESPLIEGUE.md`](docs/DESPLIEGUE.md).

La autenticación sale del backend de Guárdalo (Guardar Enlaces), adaptada: solo
el modo `deeplink`, el nombre que da el proveedor y Apple contra
`com.jmortiz.inventario`.

## Desarrollo

```bash
npm install
npm run verificar    # tipos, lint y pruebas
```

Para probarlo en local sin credenciales de Google ni de Apple:

```bash
PORT=8093 INVENTARIO_TOKEN_SECRET=local GOOGLE_CLIENT_ID=x GOOGLE_CLIENT_SECRET=x \
  PERMITIR_LOGIN_DEV=true npx tsx src/index.ts
```

`PERMITIR_LOGIN_DEV=true` abre `POST /auth/dev-login`, que da sesión con solo un
correo. Nunca en el servidor real.

npm 12 no ejecuta los scripts de instalación sin aprobarlos: `better-sqlite3`
(parte nativa) y `esbuild` están aprobados en `package.json` (`allowScripts`).

## Variables de entorno

| Variable | Qué es |
|---|---|
| `PORT` | Puerto dentro del contenedor (8081) |
| `DB_PATH` | Base de datos SQLite (`./datos/inventario.sqlite`) |
| `URL_PUBLICA` | `https://inventario.jmortiz.es`, sin barra final |
| `INVENTARIO_TOKEN_SECRET` | Firma de los tokens de acceso |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Inicio de sesión con Google |
| `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_APP_ID` | Inicio de sesión con Apple |
| `PERMITIR_LOGIN_DEV` | Solo desarrollo |
