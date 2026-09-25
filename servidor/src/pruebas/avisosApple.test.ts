import { createSign, generateKeyPairSync, type JsonWebKey } from 'node:crypto';
import Fastify, { FastifyInstance } from 'fastify';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const APP_IOS = 'com.jmortiz.inventario';
const SUB = '820417.faa325acbc78e1be1668ba852d492d8a.0219';

// Un Apple de mentira: la prueba firma los avisos y sirve la clave pública en lugar de la suya.
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const claveDeApple = {
  ...(publicKey.export({ format: 'jwk' }) as JsonWebKey),
  kty: 'RSA',
  kid: 'clave-de-apple',
  alg: 'RS256',
};
const otraClave = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;

function aviso(
  eventos: unknown,
  cambios: Record<string, unknown> = {},
  firmante = privateKey,
): string {
  const cabecera = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'clave-de-apple' })).toString('base64url');
  const cuerpo = Buffer.from(
    JSON.stringify({
      iss: 'https://appleid.apple.com',
      aud: APP_IOS,
      iat: Math.floor(Date.now() / 1000),
      jti: 'aviso-1',
      events: eventos,
      ...cambios,
    }),
  ).toString('base64url');
  const firma = createSign('RSA-SHA256').update(`${cabecera}.${cuerpo}`).sign(firmante);
  return `${cabecera}.${cuerpo}.${firma.toString('base64url')}`;
}

const evento = (tipo: string, sub = SUB) => JSON.stringify({ type: tipo, sub, event_time: 1 });

let app: FastifyInstance;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerBd: (typeof import('../db'))['obtenerBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let existeUsuario: (typeof import('../auth/usuarios'))['existeUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];
let olvidarClavesDeApple: (typeof import('../auth/appleNativo'))['olvidarClavesDeApple'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  process.env.APPLE_APP_ID = APP_IOS;
  ({ inicializarBd, obtenerBd } = await import('../db'));
  ({ obtenerOCrearUsuario, existeUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  ({ olvidarClavesDeApple } = await import('../auth/appleNativo'));
  const { registrarRutasAuth } = await import('../auth/rutas');
  app = Fastify();
  await app.register(registrarRutasAuth);
});

beforeEach(() => {
  inicializarBd(':memory:');
  olvidarClavesDeApple();
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ keys: [claveDeApple] }))));
});

function cuentaDeApple(): number {
  const id = obtenerOCrearUsuario({
    proveedor: 'apple', idProveedor: SUB, email: 'x@privaterelay.appleid.com', nombre: null, emailVerificado: true,
  })!.id;
  iniciarSesion(id, null);
  return id;
}

function sesionesAbiertas(id: number): number {
  return (
    obtenerBd()
      .prepare('SELECT COUNT(*) AS n FROM sesiones WHERE usuario_id = ? AND revocado_en IS NULL')
      .get(id) as { n: number }
  ).n;
}

async function mandar(payload: unknown) {
  return app.inject({ method: 'POST', url: '/auth/apple/avisos', payload: { payload } });
}

describe('POST /auth/apple/avisos', () => {
  it('account-deleted borra la cuenta', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('account-deleted')));
    expect(res.json()).toEqual({ ok: true });
    expect(existeUsuario(id)).toBe(false);
  });

  it('account-delete, el nombre antiguo, también', async () => {
    const id = cuentaDeApple();
    await mandar(aviso(evento('account-delete')));
    expect(existeUsuario(id)).toBe(false);
  });

  it('consent-revoked cierra las sesiones y deja la cuenta', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('consent-revoked')));
    expect(res.json()).toEqual({ ok: true });
    expect(existeUsuario(id)).toBe(true);
    expect(sesionesAbiertas(id)).toBe(0);
  });

  it('email-disabled no toca nada', async () => {
    const id = cuentaDeApple();
    await mandar(aviso(evento('email-disabled')));
    expect(existeUsuario(id)).toBe(true);
    expect(sesionesAbiertas(id)).toBe(1);
  });

  it('events como objeto, como en la documentación', async () => {
    const id = cuentaDeApple();
    await mandar(aviso({ type: 'account-deleted', sub: SUB, event_time: 1 }));
    expect(existeUsuario(id)).toBe(false);
  });

  it('de alguien sin cuenta aquí: 200 y nada más', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('account-deleted', 'otro-sub')));
    expect(res.json()).toEqual({ ok: true });
    expect(existeUsuario(id)).toBe(true);
  });

  it('no borra una cuenta de Google con el mismo sub', async () => {
    const google = obtenerOCrearUsuario({
      proveedor: 'google', idProveedor: SUB, email: 'g@ejemplo.com', nombre: null, emailVerificado: true,
    })!.id;
    await mandar(aviso(evento('account-deleted')));
    expect(existeUsuario(google)).toBe(true);
  });

  it('firmado con otra clave: 400 y no toca nada', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('account-deleted'), {}, otraClave));
    expect(res.statusCode).toBe(400);
    expect(existeUsuario(id)).toBe(true);
  });

  it('para otra app: 400', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('account-deleted'), { aud: 'com.otra.app' }));
    expect(res.statusCode).toBe(400);
    expect(existeUsuario(id)).toBe(true);
  });

  it('de otro emisor: 400', async () => {
    const id = cuentaDeApple();
    const res = await mandar(aviso(evento('account-deleted'), { iss: 'https://apple.falso.com' }));
    expect(res.statusCode).toBe(400);
    expect(existeUsuario(id)).toBe(true);
  });

  it('sin payload o sin evento legible: 400', async () => {
    expect((await mandar(undefined)).statusCode).toBe(400);
    expect((await mandar(aviso('{roto'))).statusCode).toBe(400);
    expect((await mandar(aviso(JSON.stringify({ type: 'account-deleted' })))).statusCode).toBe(400);
  });
});
