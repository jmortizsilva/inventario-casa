import { config } from './config';
import { inicializarBd } from './db';
import { purgarHogaresVacios } from './hogares/almacen';
import { crearServidor } from './servidor';

const UN_DIA_MS = 24 * 60 * 60 * 1000;

// Sin estas variables el servidor arrancaría pero fallaría en silencio (tokens firmados con un
// secreto vacío, inicio de sesión que no termina): mejor no arrancar.
// Apple solo avisa, como en Guárdalo mientras no esté configurado: /auth/iniciar ya responde 503.
function comprobarConfiguracionMinima(): void {
  const faltan: string[] = [];
  if (!config.tokenSecreto) faltan.push('INVENTARIO_TOKEN_SECRET');
  if (!config.google.clientId) faltan.push('GOOGLE_CLIENT_ID');
  if (!config.google.clientSecret) faltan.push('GOOGLE_CLIENT_SECRET');
  if (faltan.length > 0) {
    throw new Error(`faltan variables de entorno: ${faltan.join(', ')}`);
  }
  if (!config.apple.clientId || !config.apple.teamId || !config.apple.keyId || !config.apple.privateKey) {
    console.warn('Aviso: faltan variables de Apple; el inicio de sesión con Apple no funcionará.');
  }
}

async function main(): Promise<void> {
  comprobarConfiguracionMinima();
  inicializarBd();
  purgarHogaresVacios();
  setInterval(() => purgarHogaresVacios(), UN_DIA_MS).unref();
  const app = await crearServidor();
  await app.listen({ port: config.puerto, host: '0.0.0.0' });
  app.log.info(`inventario-casa escuchando en ${config.puerto}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
