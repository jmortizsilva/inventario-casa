import { generateKeyPairSync } from 'node:crypto';
import Fastify, { FastifyInstance } from 'fastify';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const APP_IOS = 'com.jmortiz.inventario';

// Clave ES256 de mentira para firmar el client_secret: Apple está simulado y no la comprueba.
const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });

let app: FastifyInstance;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let existeUsuario: (typeof import('../auth/usuarios'))['existeUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  process.env.APPLE_APP_ID = APP_IOS;
  process.env.APPLE_CLIENT_ID = 'com.ejemplo.inventario.web';
  process.env.APPLE_TEAM_ID = 'EQUIPO1234';
  process.env.APPLE_KEY_ID = 'CLAVE12345';
  process.env.APPLE_PRIVATE_KEY = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  ({ inicializarBd } = await import('../db'));
  ({ obtenerOCrearUsuario, existeUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  const { registrarRutasCuenta } = await import('../cuenta/rutas');
  app = Fastify();
  await app.register(registrarRutasCuenta);
});

beforeEach(() => {
  inicializarBd(':memory:');
});

afterEach(() => {
  vi.unstubAllGlobals();
});

function crear(proveedor: 'google' | 'apple') {
  const usuario = obtenerOCrearUsuario({
    proveedor,
    idProveedor: `sub-${proveedor}`,
    email: `${proveedor}@ejemplo.com`,
    nombre: null,
    emailVerificado: true,
  })!;
  return { id: usuario.id, headers: { authorization: `Bearer ${iniciarSesion(usuario.id, null).tokenAcceso}` } };
}

// Apple simulado: responde al canje y a la revocación, y guarda lo que se le pidió.
function simularApple(canje: { status: number; cuerpo: unknown }, revocacion = { status: 200 }) {
  const peticiones: { url: string; cuerpo: URLSearchParams }[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, opciones: { body: URLSearchParams }) => {
      peticiones.push({ url, cuerpo: opciones.body });
      if (url.endsWith('/auth/token')) {
        return new Response(JSON.stringify(canje.cuerpo), { status: canje.status });
      }
      return new Response(null, { status: revocacion.status });
    }),
  );
  return peticiones;
}

describe('DELETE /cuenta', () => {
  it('sin sesión: 401', async () => {
    const res = await app.inject({ method: 'DELETE', url: '/cuenta' });
    expect(res.statusCode).toBe(401);
  });

  it('cuenta de Google: se borra sin cuerpo y sin hablar con nadie', async () => {
    const fetch = vi.fn();
    vi.stubGlobal('fetch', fetch);
    const ana = crear('google');

    const res = await app.inject({ method: 'DELETE', url: '/cuenta', headers: ana.headers });

    expect(res.json()).toEqual({ ok: true });
    expect(existeUsuario(ana.id)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });

  it('después de borrarla, el mismo token ya no vale', async () => {
    const ana = crear('google');
    await app.inject({ method: 'DELETE', url: '/cuenta', headers: ana.headers });
    const otraVez = await app.inject({ method: 'DELETE', url: '/cuenta', headers: ana.headers });
    expect(otraVez.statusCode).toBe(401);
  });

  it('cuenta de Apple sin código: 400 y no se borra', async () => {
    const ana = crear('apple');
    const res = await app.inject({ method: 'DELETE', url: '/cuenta', headers: ana.headers });
    expect(res.statusCode).toBe(400);
    expect(res.json()).toEqual({ error: 'falta_codigo_apple' });
    expect(existeUsuario(ana.id)).toBe(true);
  });

  it('cuenta de Apple: canjea el código con el id de la app, revoca y borra', async () => {
    const peticiones = simularApple({ status: 200, cuerpo: { refresh_token: 'refresco-de-apple' } });
    const ana = crear('apple');

    const res = await app.inject({
      method: 'DELETE', url: '/cuenta', headers: ana.headers, payload: { codigoApple: 'codigo-1' },
    });

    expect(res.json()).toEqual({ ok: true });
    expect(existeUsuario(ana.id)).toBe(false);

    const [canje, revocacion] = peticiones;
    expect(canje.url).toBe('https://appleid.apple.com/auth/token');
    expect(canje.cuerpo.get('client_id')).toBe(APP_IOS);
    expect(canje.cuerpo.get('code')).toBe('codigo-1');
    expect(canje.cuerpo.get('grant_type')).toBe('authorization_code');
    expect(canje.cuerpo.has('redirect_uri')).toBe(false);
    // El client_secret va firmado para la app, no para el Services ID.
    const secreto = JSON.parse(Buffer.from(canje.cuerpo.get('client_secret')!.split('.')[1], 'base64url').toString());
    expect(secreto).toMatchObject({ iss: 'EQUIPO1234', sub: APP_IOS, aud: 'https://appleid.apple.com' });

    expect(revocacion.url).toBe('https://appleid.apple.com/auth/revoke');
    expect(revocacion.cuerpo.get('client_id')).toBe(APP_IOS);
    expect(revocacion.cuerpo.get('token')).toBe('refresco-de-apple');
    expect(revocacion.cuerpo.get('token_type_hint')).toBe('refresh_token');
  });

  it('código caducado o usado: 400 y no se borra', async () => {
    simularApple({ status: 400, cuerpo: { error: 'invalid_grant' } });
    const ana = crear('apple');

    const res = await app.inject({
      method: 'DELETE', url: '/cuenta', headers: ana.headers, payload: { codigoApple: 'viejo' },
    });

    expect(res.statusCode).toBe(400);
    expect(res.json()).toEqual({ error: 'codigo_apple_no_valido' });
    expect(existeUsuario(ana.id)).toBe(true);
  });

  it('si Apple rechaza nuestras credenciales: 502 y no se borra', async () => {
    simularApple({ status: 400, cuerpo: { error: 'invalid_client' } });
    const ana = crear('apple');

    const res = await app.inject({
      method: 'DELETE', url: '/cuenta', headers: ana.headers, payload: { codigoApple: 'codigo-1' },
    });

    expect(res.statusCode).toBe(502);
    expect(existeUsuario(ana.id)).toBe(true);
  });

  it('si falla la revocación: 502 y no se borra', async () => {
    simularApple({ status: 200, cuerpo: { refresh_token: 'r' } }, { status: 400 });
    const ana = crear('apple');

    const res = await app.inject({
      method: 'DELETE', url: '/cuenta', headers: ana.headers, payload: { codigoApple: 'codigo-1' },
    });

    expect(res.statusCode).toBe(502);
    expect(existeUsuario(ana.id)).toBe(true);
  });

  it('sin conexión con Apple: 502 y no se borra', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new TypeError('fetch failed'); }));
    const ana = crear('apple');

    const res = await app.inject({
      method: 'DELETE', url: '/cuenta', headers: ana.headers, payload: { codigoApple: 'codigo-1' },
    });

    expect(res.statusCode).toBe(502);
    expect(existeUsuario(ana.id)).toBe(true);
  });
});

describe('PUT /cuenta/nombre', () => {
  it('guarda el nombre limpio y devuelve el usuario', async () => {
    const ana = crear('apple');
    const res = await app.inject({
      method: 'PUT', url: '/cuenta/nombre', headers: ana.headers, payload: { nombre: '  Ana   María ' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().usuario).toMatchObject({ id: ana.id, nombre: 'Ana María', proveedor: 'apple' });
  });

  it('vacío o de más de 100 letras: 400', async () => {
    const ana = crear('google');
    for (const nombre of ['   ', 'a'.repeat(101), 42]) {
      const res = await app.inject({ method: 'PUT', url: '/cuenta/nombre', headers: ana.headers, payload: { nombre } });
      expect(res.statusCode).toBe(400);
    }
  });

  it('sin sesión: 401', async () => {
    const res = await app.inject({ method: 'PUT', url: '/cuenta/nombre', payload: { nombre: 'Ana' } });
    expect(res.statusCode).toBe(401);
  });

  it('volver a entrar con Google no pisa el nombre elegido', async () => {
    const ana = crear('google');
    await app.inject({ method: 'PUT', url: '/cuenta/nombre', headers: ana.headers, payload: { nombre: 'Anita' } });
    const otraVez = obtenerOCrearUsuario({
      proveedor: 'google', idProveedor: 'sub-google', email: 'google@ejemplo.com', nombre: 'Ana López', emailVerificado: true,
    })!;
    expect(otraVez.nombre).toBe('Anita');
  });
});
