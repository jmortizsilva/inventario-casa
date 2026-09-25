// Configuración leída del entorno: podman-compose la inyecta desde el .env del servidor.

export const config = {
  // 8081 por dentro del contenedor, como Guárdalo; fuera se publica en otro puerto.
  puerto: Number(process.env.PORT ?? 8081),
  rutaBd: process.env.DB_PATH ?? './datos/inventario.sqlite',

  // URL pública HTTPS, sin barra final. Con ella se construye la dirección de vuelta que se
  // registra en Google y en Apple, y tiene que coincidir carácter a carácter.
  urlPublica: process.env.URL_PUBLICA ?? 'http://localhost:8081',

  // Firma los tokens de acceso (HMAC). Sin él el servidor no arranca (ver index.ts).
  tokenSecreto: process.env.INVENTARIO_TOKEN_SECRET,

  google: {
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
  },
  apple: {
    // Services ID de Sign in with Apple: el client_id del inicio de sesión por navegador.
    clientId: process.env.APPLE_CLIENT_ID,
    // Identificador de la app de iOS: la audiencia del token cuando se entra desde la propia app.
    // Admite varios separados por comas.
    appIds: (process.env.APPLE_APP_ID ?? 'com.jmortiz.inventario')
      .split(',')
      .map((id) => id.trim())
      .filter((id) => id.length > 0),
    teamId: process.env.APPLE_TEAM_ID,
    keyId: process.env.APPLE_KEY_ID,
    // Clave .p8 en una sola línea con los saltos escapados como "\n": un .env no guarda bien un
    // valor de varias líneas. Aquí se deshacen.
    privateKey: process.env.APPLE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  },

  // SOLO DESARROLLO: activa POST /auth/dev-login, que da sesión con solo un correo. Sin esta
  // variable a 'true' la ruta ni se registra.
  permitirLoginDev: process.env.PERMITIR_LOGIN_DEV === 'true',
};
