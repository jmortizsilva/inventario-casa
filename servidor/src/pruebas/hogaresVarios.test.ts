import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import formbody from '@fastify/formbody';
import Database from 'better-sqlite3';
import Fastify, { FastifyInstance } from 'fastify';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { Entorno } from '../avisos/almacen';
import type { Enviador, Notificacion, ResultadoEnvio } from '../avisos/apns';

class EnviadorDePrueba implements Enviador {
  enviadas: { token: string; n: Notificacion }[] = [];
  async enviar(token: string, _entorno: Entorno, n: Notificacion): Promise<ResultadoEnvio> {
    this.enviadas.push({ token, n });
    return 'enviada';
  }
}

let app: FastifyInstance;
let enviador: EnviadorDePrueba;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerBd: (typeof import('../db'))['obtenerBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];
let usarEnviador: (typeof import('../avisos/avisar'))['usarEnviador'];
let borrarCuenta: (typeof import('../cuenta/almacen'))['borrarCuenta'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  ({ inicializarBd, obtenerBd } = await import('../db'));
  ({ obtenerOCrearUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  ({ usarEnviador } = await import('../avisos/avisar'));
  ({ borrarCuenta } = await import('../cuenta/almacen'));
  const { registrarRutasHogar } = await import('../hogares/rutas');
  const { registrarRutasSincronizacion } = await import('../sincronizacion/rutas');
  const { registrarRutasAvisos } = await import('../avisos/rutas');
  app = Fastify();
  await app.register(formbody);
  await app.register(registrarRutasHogar);
  await app.register(registrarRutasSincronizacion);
  await app.register(registrarRutasAvisos);
});

beforeEach(() => {
  inicializarBd(':memory:');
  enviador = new EnviadorDePrueba();
  usarEnviador(enviador);
});

afterEach(() => usarEnviador(undefined));

function persona(nombre: string) {
  const u = obtenerOCrearUsuario({
    proveedor: 'google', idProveedor: `sub-${nombre}`, email: `${nombre}@ejemplo.com`, nombre, emailVerificado: true,
  })!;
  return { id: u.id, headers: { authorization: `Bearer ${iniciarSesion(u.id, null).tokenAcceso}` } };
}

type Quien = ReturnType<typeof persona>;
const pedir = (quien: Quien, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
  app.inject({ method, url, headers: quien.headers, payload });

async function crear(quien: Quien, nombre: string): Promise<string> {
  const r = await pedir(quien, 'POST', '/hogares', { nombre });
  expect(r.statusCode).toBe(201);
  return r.json().hogar.id;
}

async function invitarYUnir(dueno: Quien, hogarId: string, invitado: Quien) {
  const { codigo } = (await pedir(dueno, 'POST', `/hogares/${hogarId}/invitaciones`)).json();
  return pedir(invitado, 'POST', '/hogares/unirse', { codigo });
}

const esperar = () => new Promise((r) => setTimeout(r, 20));

describe('varios hogares', () => {
  it('se crean varios, en orden, y el primero es el de las rutas antiguas', async () => {
    const ana = persona('Ana');
    const casa = await crear(ana, 'Casa');
    const playa = await crear(ana, 'Playa');

    const lista = (await pedir(ana, 'GET', '/hogares')).json().hogares;
    expect(lista.map((h: { nombre: string }) => h.nombre)).toEqual(['Casa', 'Playa']);
    expect((await pedir(ana, 'GET', '/hogar')).json().hogar.id).toBe(casa);
    expect(playa).not.toBe(casa);
  });

  it('las rutas antiguas no dejan crear ni unirse a un segundo', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    await crear(ana, 'Casa');
    const deLuis = await crear(luis, 'Piso');
    expect((await pedir(ana, 'POST', '/hogar', { nombre: 'Otra' })).statusCode).toBe(409);
    const { codigo } = (await pedir(luis, 'POST', `/hogares/${deLuis}/invitaciones`)).json();
    expect((await pedir(ana, 'POST', '/hogar/unirse', { codigo })).statusCode).toBe(409);
  });

  it('como mucho 10', async () => {
    const ana = persona('Ana');
    for (let i = 0; i < 10; i++) await crear(ana, `Hogar ${i}`);
    const once = await pedir(ana, 'POST', '/hogares', { nombre: 'Once' });
    expect(once.statusCode).toBe(409);
    expect(once.json()).toEqual({ error: 'limite_hogares' });
  });

  it('unirse a otro sin salir del suyo; al propio, 409 sin gastar la invitación', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    const casa = await crear(ana, 'Casa');
    await crear(luis, 'Piso');

    const unido = await invitarYUnir(ana, casa, luis);
    expect(unido.statusCode).toBe(200);
    expect((await pedir(luis, 'GET', '/hogares')).json().hogares.map((h: { nombre: string }) => h.nombre)).toEqual([
      'Piso',
      'Casa',
    ]);

    const { codigo } = (await pedir(ana, 'POST', `/hogares/${casa}/invitaciones`)).json();
    const otraVez = await pedir(luis, 'POST', '/hogares/unirse', { codigo });
    expect(otraVez.statusCode).toBe(409);
    expect(otraVez.json()).toEqual({ error: 'ya_en_este_hogar' });
    // La invitación sigue valiendo para quien iba.
    expect((await pedir(persona('Eva'), 'POST', '/hogares/unirse', { codigo })).statusCode).toBe(200);
  });

  it('el inventario de cada hogar va por separado', async () => {
    const ana = persona('Ana');
    const casa = await crear(ana, 'Casa');
    const playa = await crear(ana, 'Playa');
    await pedir(ana, 'POST', `/hogares/${casa}/sincronizar`, {
      categorias: [{ id: 'c1', nombre: 'Despensa', creado: 1, modificado: 1 }],
    });

    expect((await pedir(ana, 'GET', `/hogares/${casa}/sincronizar?desde=0`)).json().categorias).toHaveLength(1);
    expect((await pedir(ana, 'GET', `/hogares/${playa}/sincronizar?desde=0`)).json().categorias).toHaveLength(0);
    // Y un id de otro hogar no se puede pisar desde este.
    const pisar = await pedir(ana, 'POST', `/hogares/${playa}/sincronizar`, {
      categorias: [{ id: 'c1', nombre: 'Robada', creado: 1, modificado: 9 }],
    });
    expect(pisar.json().rechazados).toEqual([{ tipo: 'categoria', id: 'c1', motivo: 'no_aplicable' }]);
  });

  it('en un hogar ajeno, 404 como si no existiera', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    const casa = await crear(ana, 'Casa');
    for (const [metodo, ruta] of [
      ['GET', `/hogares/${casa}/sincronizar`],
      ['POST', `/hogares/${casa}/sincronizar`],
      ['POST', `/hogares/${casa}/invitaciones`],
      ['POST', `/hogares/${casa}/salir`],
      ['GET', `/hogares/${casa}/avisos`],
      ['GET', '/hogares/no-existe/sincronizar'],
    ] as const) {
      expect((await pedir(luis, metodo, ruta, metodo === 'POST' ? {} : undefined)).statusCode, `${metodo} ${ruta}`).toBe(404);
    }
  });

  it('salir de uno deja los demás, y sus notificaciones de ese hogar', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    const casa = await crear(ana, 'Casa');
    await crear(luis, 'Piso');
    await invitarYUnir(ana, casa, luis);
    await pedir(luis, 'PUT', `/hogares/${casa}/avisos`, { productosNuevos: true });

    await pedir(luis, 'POST', `/hogares/${casa}/salir`);

    expect((await pedir(luis, 'GET', '/hogares')).json().hogares.map((h: { nombre: string }) => h.nombre)).toEqual(['Piso']);
    expect(obtenerBd().prepare('SELECT COUNT(*) AS n FROM avisos WHERE usuario_id = ?').get(luis.id)).toEqual({ n: 0 });
  });
});

describe('notificaciones por hogar', () => {
  it('llegan según lo elegido en cada hogar, esté abierto o no', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    const casa = await crear(ana, 'Casa');
    const playa = await crear(ana, 'Playa');
    await invitarYUnir(ana, casa, luis);
    await invitarYUnir(ana, playa, luis);
    await pedir(luis, 'PUT', '/dispositivos', { token: 'aa'.repeat(32), plataforma: 'ios', entorno: 'produccion' });
    await pedir(luis, 'PUT', `/hogares/${casa}/avisos`, { categoriasNuevas: true });
    await esperar();
    enviador.enviadas = [];

    await pedir(ana, 'POST', `/hogares/${playa}/sincronizar`, {
      categorias: [{ id: 'c1', nombre: 'Toallas', creado: 1, modificado: 1 }],
    });
    await pedir(ana, 'POST', `/hogares/${casa}/sincronizar`, {
      categorias: [{ id: 'c2', nombre: 'Despensa', creado: 1, modificado: 1 }],
    });
    await esperar();

    expect(enviador.enviadas.map((e) => [e.n.titulo, e.n.cuerpo])).toEqual([
      ['Casa', 'Ana ha añadido la categoría Despensa'],
    ]);
    expect((await pedir(luis, 'GET', `/hogares/${playa}/avisos`)).json().categoriasNuevas).toBe(false);
  });
});

describe('borrar la cuenta con varios hogares', () => {
  it('se borran los hogares en los que estaba sola; los compartidos siguen', async () => {
    const ana = persona('Ana');
    const luis = persona('Luis');
    const sola = await crear(ana, 'Solo mío');
    const compartido = await crear(ana, 'Casa');
    await invitarYUnir(ana, compartido, luis);

    borrarCuenta(ana.id);

    const hogares = obtenerBd().prepare('SELECT id FROM hogares').all() as { id: string }[];
    expect(hogares.map((h) => h.id)).toEqual([compartido]);
    expect(hogares.map((h) => h.id)).not.toContain(sola);
  });
});

describe('migración de una base con un hogar por persona', () => {
  let carpeta: string;
  afterEach(() => rmSync(carpeta, { recursive: true, force: true }));

  it('conserva miembros y pasa las notificaciones a su hogar', () => {
    carpeta = mkdtempSync(join(tmpdir(), 'inventario-'));
    const ruta = join(carpeta, 'inventario.sqlite');
    // Las tablas como estaban hasta el 27 de septiembre de 2026.
    const vieja = new Database(ruta);
    vieja.exec(`
      CREATE TABLE usuarios (id INTEGER PRIMARY KEY AUTOINCREMENT, proveedor TEXT NOT NULL, id_proveedor TEXT NOT NULL,
        email TEXT NOT NULL, nombre TEXT, creado_en INTEGER NOT NULL, activo INTEGER NOT NULL DEFAULT 1,
        UNIQUE (proveedor, id_proveedor));
      CREATE TABLE hogares (id TEXT PRIMARY KEY, nombre TEXT NOT NULL, creado_en INTEGER NOT NULL,
        revision INTEGER NOT NULL DEFAULT 0, vacio_desde INTEGER);
      CREATE TABLE miembros (usuario_id INTEGER PRIMARY KEY REFERENCES usuarios(id),
        hogar_id TEXT NOT NULL REFERENCES hogares(id), unido_en INTEGER NOT NULL);
      CREATE TABLE avisos (usuario_id INTEGER PRIMARY KEY REFERENCES usuarios(id),
        productos_nuevos INTEGER NOT NULL DEFAULT 0, categorias_nuevas INTEGER NOT NULL DEFAULT 0,
        entra_en_lista INTEGER NOT NULL DEFAULT 0, sale_de_lista INTEGER NOT NULL DEFAULT 0,
        personas_nuevas INTEGER NOT NULL DEFAULT 0);
      INSERT INTO usuarios (id, proveedor, id_proveedor, email, creado_en) VALUES (1, 'google', 'a', 'a@e.com', 1);
      INSERT INTO hogares (id, nombre, creado_en) VALUES ('h1', 'Casa', 1);
      INSERT INTO miembros VALUES (1, 'h1', 5);
      INSERT INTO avisos (usuario_id, entra_en_lista) VALUES (1, 1);
    `);
    vieja.close();

    const bd = inicializarBd(ruta);

    const clave = (bd.pragma('table_info(miembros)') as { name: string; pk: number }[]).filter((c) => c.pk > 0);
    expect(clave.map((c) => c.name).sort()).toEqual(['hogar_id', 'usuario_id']);
    expect(bd.prepare('SELECT usuario_id, hogar_id, unido_en FROM miembros').all()).toEqual([
      { usuario_id: 1, hogar_id: 'h1', unido_en: 5 },
    ]);
    expect(bd.prepare('SELECT usuario_id, hogar_id, entra_en_lista FROM avisos').all()).toEqual([
      { usuario_id: 1, hogar_id: 'h1', entra_en_lista: 1 },
    ]);

    // Y abrirla otra vez no vuelve a tocar nada.
    bd.close();
    const otraVez = inicializarBd(ruta);
    expect(otraVez.prepare('SELECT COUNT(*) AS n FROM miembros').get()).toEqual({ n: 1 });
    otraVez.close();
  });
});
