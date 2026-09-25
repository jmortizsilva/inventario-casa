import { config } from '../config';
import { generarClientSecretApple } from '../auth/oauth';

// Revocar el acceso en Apple al borrar una cuenta, como exige Apple (ver CONTRATO-API.md,
// DELETE /cuenta). El servidor no guarda tokens de Apple: la app pide a la persona que se
// identifique otra vez y manda el authorizationCode, que aquí se canjea por un token de refresco
// para revocarlo en el acto.

export type ResultadoRevocar = 'revocado' | 'codigo_no_valido' | 'fallo_apple';

interface RespuestaToken {
  refresh_token?: string;
  error?: string;
}

export async function revocarAccesoApple(
  codigo: string,
  ahora: () => number = () => Date.now(),
): Promise<ResultadoRevocar> {
  // El código lo da la app de iOS, así que se canjea con el identificador de la app y no con el
  // Services ID. Si algún día hay dos apps, la actual va primera en APPLE_APP_ID.
  const clientId = config.apple.appIds[0];
  const clientSecret = generarClientSecretApple(ahora, clientId);

  let canje: Response;
  try {
    // Sin redirect_uri: Apple solo lo pide si iba en la autorización, y la app nativa no lo manda.
    canje = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code: codigo,
        grant_type: 'authorization_code',
      }),
    });
  } catch {
    return 'fallo_apple';
  }
  const datos = (await canje.json().catch(() => ({}))) as RespuestaToken;
  if (!canje.ok || !datos.refresh_token) {
    // invalid_grant es el código caducado (dura 5 minutos), ya usado o de otra app: la app
    // puede pedir otro. Cualquier otro error es nuestro (clave o identificadores mal puestos).
    return datos.error === 'invalid_grant' ? 'codigo_no_valido' : 'fallo_apple';
  }

  try {
    const revocacion = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        token: datos.refresh_token,
        token_type_hint: 'refresh_token',
      }),
    });
    return revocacion.ok ? 'revocado' : 'fallo_apple';
  } catch {
    return 'fallo_apple';
  }
}
