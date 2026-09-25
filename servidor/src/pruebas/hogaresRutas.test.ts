import formbody from '@fastify/formbody';
import Fastify, { FastifyInstance } from 'fastify';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

let app: FastifyInstance;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  ({ inicializarBd } = await import('../db'));
  ({ obtenerOCrearUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  const { registrarRutasHogar } = await import('../hogares/rutas');
  app = Fastify();
  await app.register(formbody);
  await app.register(registrarRutasHogar);
});

beforeEach(() => {
  inicializarBd(':memory:');
});

function cabecera(nombre: string) {
  const usuario = obtenerOCrearUsuario({
    proveedor: 'google',
    idProveedor: `sub-${nombre}`,
    email: `${nombre.toLowerCase()}@ejemplo.com`,
    nombre,
    emailVerificado: true,
  })!;
  return { authorization: `Bearer ${iniciarSesion(usuario.id, null).tokenAcceso}` };
}

describe('rutas de /hogar', () => {
  it('sin sesión: 401', async () => {
    const res = await app.inject({ method: 'GET', url: '/hogar' });
    expect(res.statusCode).toBe(401);
  });

  it('sin hogar devuelve null', async () => {
    const res = await app.inject({ method: 'GET', url: '/hogar', headers: cabecera('Ana') });
    expect(res.json()).toEqual({ hogar: null });
  });

  it('crear, invitar, unirse y salir', async () => {
    const ana = cabecera('Ana');
    const luis = cabecera('Luis');

    const creado = await app.inject({ method: 'POST', url: '/hogar', headers: ana, payload: { nombre: ' Casa ' } });
    expect(creado.statusCode).toBe(201);
    expect(creado.json().hogar.nombre).toBe('Casa');

    const repetido = await app.inject({ method: 'POST', url: '/hogar', headers: ana, payload: { nombre: 'Otra' } });
    expect(repetido.statusCode).toBe(409);

    const invitacion = await app.inject({ method: 'POST', url: '/hogar/invitaciones', headers: ana });
    expect(invitacion.statusCode).toBe(201);
    const { codigo } = invitacion.json();

    const unido = await app.inject({ method: 'POST', url: '/hogar/unirse', headers: luis, payload: { codigo } });
    expect(unido.statusCode).toBe(200);
    expect(unido.json().hogar.miembros.map((m: { nombre: string }) => m.nombre)).toEqual(['Ana', 'Luis']);

    const otraVez = await app.inject({ method: 'POST', url: '/hogar/unirse', headers: cabecera('Eva'), payload: { codigo } });
    expect(otraVez.statusCode).toBe(404);

    const salida = await app.inject({ method: 'POST', url: '/hogar/salir', headers: luis });
    expect(salida.json()).toEqual({ ok: true });
    const sinHogar = await app.inject({ method: 'GET', url: '/hogar', headers: luis });
    expect(sinHogar.json()).toEqual({ hogar: null });
  });

  it('nombre no válido: 400', async () => {
    const res = await app.inject({ method: 'POST', url: '/hogar', headers: cabecera('Ana'), payload: { nombre: '  ' } });
    expect(res.statusCode).toBe(400);
  });

  it('invitar o salir sin hogar: 409', async () => {
    const ana = cabecera('Ana');
    expect((await app.inject({ method: 'POST', url: '/hogar/invitaciones', headers: ana })).statusCode).toBe(409);
    expect((await app.inject({ method: 'POST', url: '/hogar/salir', headers: ana })).statusCode).toBe(409);
  });

  it('demasiados intentos: 429', async () => {
    const eva = cabecera('Eva');
    for (let i = 0; i < 10; i++) {
      await app.inject({ method: 'POST', url: '/hogar/unirse', headers: eva, payload: { codigo: `MALO${i}` } });
    }
    const res = await app.inject({ method: 'POST', url: '/hogar/unirse', headers: eva, payload: { codigo: 'X' } });
    expect(res.statusCode).toBe(429);
  });
});
