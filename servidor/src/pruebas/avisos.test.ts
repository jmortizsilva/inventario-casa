import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import formbody from '@fastify/formbody';
import Fastify, { FastifyInstance } from 'fastify';
import { afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { Entorno } from '../avisos/almacen';
import type { Enviador, Notificacion, ResultadoEnvio } from '../avisos/apns';
import { interpretar } from '../avisos/apns';
import * as textos from '../avisos/textos';
import { estaEnLista } from '../sincronizacion/reglas';

// Apple de mentira: guarda lo que se le manda y contesta lo que diga `respuesta`.
class EnviadorDePrueba implements Enviador {
  enviadas: { token: string; entorno: Entorno; n: Notificacion }[] = [];
  respuesta: ResultadoEnvio = 'enviada';
  async enviar(token: string, entorno: Entorno, n: Notificacion): Promise<ResultadoEnvio> {
    this.enviadas.push({ token, entorno, n });
    return this.respuesta;
  }
}

const TOKEN_LUIS = 'aa'.repeat(32);
const TOKEN_ANA = 'bb'.repeat(32);

let app: FastifyInstance;
let enviador: EnviadorDePrueba;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerBd: (typeof import('../db'))['obtenerBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];
let usarEnviador: (typeof import('../avisos/avisar'))['usarEnviador'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  ({ inicializarBd, obtenerBd } = await import('../db'));
  ({ obtenerOCrearUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  ({ usarEnviador } = await import('../avisos/avisar'));
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

function persona(nombre: string | null, sub: string) {
  const u = obtenerOCrearUsuario({ proveedor: 'google', idProveedor: sub, email: `${sub}@ejemplo.com`, nombre, emailVerificado: true })!;
  return { id: u.id, headers: { authorization: `Bearer ${iniciarSesion(u.id, null).tokenAcceso}` } };
}

// Las notificaciones salen sin esperar a la respuesta: se deja correr lo pendiente.
const esperar = () => new Promise((r) => setTimeout(r, 20));

async function hogarDeAnaYLuis() {
  const ana = persona('Ana', 'ana');
  const luis = persona('Luis', 'luis');
  await app.inject({ method: 'POST', url: '/hogar', headers: ana.headers, payload: { nombre: 'Casa' } });
  const { codigo } = (await app.inject({ method: 'POST', url: '/hogar/invitaciones', headers: ana.headers })).json();
  await app.inject({ method: 'POST', url: '/hogar/unirse', headers: luis.headers, payload: { codigo } });
  await app.inject({
    method: 'PUT', url: '/dispositivos', headers: luis.headers,
    payload: { token: TOKEN_LUIS, plataforma: 'ios', entorno: 'produccion' },
  });
  await app.inject({
    method: 'PUT', url: '/dispositivos', headers: ana.headers,
    payload: { token: TOKEN_ANA, plataforma: 'ios', entorno: 'produccion' },
  });
  await esperar();
  enviador.enviadas = [];
  return { ana, luis };
}

const todos = { productosNuevos: true, categoriasNuevas: true, entraEnLista: true, saleDeLista: true, personasNuevas: true };
const prod = (id: string, extra: object = {}) => ({
  id, categoriaId: 'c1', nombre: 'Leche', umbralCompra: 1, autoListaCompra: true, enListaCompraManual: false,
  creado: 1, modificado: 1, ...extra,
});

describe('textos de las notificaciones', () => {
  it('productos y categorías', () => {
    expect(textos.productosNuevos('Ana', ['Leche'])).toBe('Ana ha añadido Leche');
    expect(textos.productosNuevos('Ana', ['Leche', 'Pan'])).toBe('Ana ha añadido Leche y 1 producto más');
    expect(textos.productosNuevos('Ana', ['Leche', 'Pan', 'Sal', 'Té'])).toBe('Ana ha añadido Leche y 3 productos más');
    expect(textos.categoriasNuevas('Ana', ['Limpieza'])).toBe('Ana ha añadido la categoría Limpieza');
    expect(textos.categoriasNuevas('Ana', ['Limpieza', 'Baño', 'Nevera'])).toBe('Ana ha añadido la categoría Limpieza y 2 más');
  });

  it('la lista', () => {
    expect(textos.entranEnLista(['Leche'])).toBe('A la lista: Leche');
    expect(textos.entranEnLista(['Leche', 'Pan'])).toBe('A la lista: Leche y Pan');
    expect(textos.entranEnLista(['Leche', 'Pan', 'Sal', 'Té'])).toBe('A la lista: Leche, Pan y 2 más');
    expect(textos.salenDeLista(['Leche', 'Pan', 'Sal'])).toBe('Fuera de la lista: Leche, Pan y 1 más');
  });

  it('personas', () => {
    expect(textos.personaNueva('Luis')).toBe('Luis se ha unido al hogar');
    expect(textos.personaNueva(null)).toBe('Alguien se ha unido al hogar');
  });
});

describe('regla de la lista (casos compartidos)', () => {
  type Caso = { caso: string; enLista: boolean } & Parameters<typeof estaEnLista>[0];
  const casos: Caso[] = JSON.parse(readFileSync(join(__dirname, '../../../pruebas-compartidas/lista-compra.json'), 'utf8')).casos;
  it.each(casos)('$caso', (caso) => {
    expect(estaEnLista(caso)).toBe(caso.enLista);
  });
});

describe('preferencias', () => {
  it('empiezan desactivadas, se cambian por partes y se validan', async () => {
    const ana = persona('Ana', 'ana');
    // Son de cada hogar: sin hogar no hay dónde guardarlas.
    const sinHogar = await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: ana.headers, payload: { entraEnLista: true } });
    expect(sinHogar.statusCode).toBe(409);
    await app.inject({ method: 'POST', url: '/hogar', headers: ana.headers, payload: { nombre: 'Casa' } });
    expect((await app.inject({ method: 'GET', url: '/cuenta/avisos', headers: ana.headers })).json()).toEqual({
      productosNuevos: false, categoriasNuevas: false, entraEnLista: false, saleDeLista: false, personasNuevas: false,
    });
    const cambiado = await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: ana.headers, payload: { entraEnLista: true } });
    expect(cambiado.json()).toMatchObject({ entraEnLista: true, productosNuevos: false });
    const malo = await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: ana.headers, payload: { entraEnLista: 'sí' } });
    expect(malo.statusCode).toBe(400);
  });
});

describe('dispositivos', () => {
  it('un token que tenía otra cuenta pasa a la nueva, y solo su dueño lo quita', async () => {
    const ana = persona('Ana', 'ana');
    const luis = persona('Luis', 'luis');
    const alta = (quien: typeof ana) => app.inject({
      method: 'PUT', url: '/dispositivos', headers: quien.headers,
      payload: { token: TOKEN_ANA, plataforma: 'ios', entorno: 'produccion' },
    });
    await alta(ana);
    await alta(luis);
    const dueno = () => (obtenerBd().prepare('SELECT usuario_id FROM dispositivos WHERE token = ?').get(TOKEN_ANA) as { usuario_id: number } | undefined)?.usuario_id;
    expect(dueno()).toBe(luis.id);
    await app.inject({ method: 'DELETE', url: `/dispositivos/${TOKEN_ANA}`, headers: ana.headers });
    expect(dueno()).toBe(luis.id);
    await app.inject({ method: 'DELETE', url: `/dispositivos/${TOKEN_ANA}`, headers: luis.headers });
    expect(dueno()).toBeUndefined();
  });

  it('datos no válidos: 400', async () => {
    const ana = persona('Ana', 'ana');
    for (const payload of [{ token: 'x', plataforma: 'ios', entorno: 'produccion' }, { token: TOKEN_ANA, plataforma: 'windows', entorno: 'produccion' }, { token: TOKEN_ANA, plataforma: 'ios', entorno: 'otro' }]) {
      expect((await app.inject({ method: 'PUT', url: '/dispositivos', headers: ana.headers, payload })).statusCode).toBe(400);
    }
  });
});

describe('avisar', () => {
  it('lo que añade Ana le llega a Luis, a ella no, y agrupado por tipo', async () => {
    const { ana, luis } = await hogarDeAnaYLuis();
    await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: luis.headers, payload: todos });
    await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: ana.headers, payload: todos });

    const respuesta = await app.inject({
      method: 'POST', url: '/sincronizar', headers: ana.headers,
      payload: {
        categorias: [{ id: 'c1', nombre: 'Nevera', creado: 1, modificado: 1 }],
        productos: [prod('p1', { cantidad: 0, cantidadFijadaEn: 1 }), prod('p2', { nombre: 'Pan', cantidad: 5, cantidadFijadaEn: 1 })],
      },
    });
    await esperar();

    // Los sucesos no salen en la respuesta.
    expect(respuesta.json().sucesos).toBeUndefined();
    expect(enviador.enviadas.every((e) => e.token === TOKEN_LUIS)).toBe(true);
    expect(enviador.enviadas.map((e) => e.n.cuerpo)).toEqual([
      'Ana ha añadido Leche y 1 producto más',
      'Ana ha añadido la categoría Nevera',
      'A la lista: Leche',
    ]);
    expect(enviador.enviadas[0].n.titulo).toBe('Casa');
  });

  it('entrar y salir de la lista con los toques; borrar no es salir', async () => {
    const { ana, luis } = await hogarDeAnaYLuis();
    await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: luis.headers, payload: { entraEnLista: true, saleDeLista: true } });
    await app.inject({
      method: 'POST', url: '/sincronizar', headers: ana.headers,
      payload: { categorias: [{ id: 'c1', nombre: 'Nevera', creado: 1, modificado: 1 }], productos: [prod('p1', { cantidad: 2, cantidadFijadaEn: 1 })] },
    });
    await esperar();
    expect(enviador.enviadas).toEqual([]);

    await app.inject({ method: 'POST', url: '/sincronizar', headers: ana.headers, payload: { movimientos: [{ id: 'm1', productoId: 'p1', cambio: -1, momento: 5 }] } });
    await esperar();
    expect(enviador.enviadas.map((e) => e.n.cuerpo)).toEqual(['A la lista: Leche']);

    await app.inject({ method: 'POST', url: '/sincronizar', headers: ana.headers, payload: { movimientos: [{ id: 'm2', productoId: 'p1', cambio: 3, momento: 6 }] } });
    await esperar();
    expect(enviador.enviadas.map((e) => e.n.cuerpo).at(-1)).toBe('Fuera de la lista: Leche');

    enviador.enviadas = [];
    await app.inject({ method: 'POST', url: '/sincronizar', headers: ana.headers, payload: { movimientos: [{ id: 'm3', productoId: 'p1', cambio: -5, momento: 7 }] } });
    await app.inject({ method: 'POST', url: '/sincronizar', headers: ana.headers, payload: { productos: [prod('p1', { modificado: 9, borrado: true })] } });
    await esperar();
    expect(enviador.enviadas.map((e) => e.n.cuerpo)).toEqual(['A la lista: Leche']);
  });

  it('sin la preferencia activada no llega nada', async () => {
    const { ana } = await hogarDeAnaYLuis();
    await app.inject({
      method: 'POST', url: '/sincronizar', headers: ana.headers,
      payload: { categorias: [{ id: 'c1', nombre: 'Nevera', creado: 1, modificado: 1 }] },
    });
    await esperar();
    expect(enviador.enviadas).toEqual([]);
  });

  it('un token que Apple ya no acepta se borra', async () => {
    const { ana, luis } = await hogarDeAnaYLuis();
    await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: luis.headers, payload: todos });
    enviador.respuesta = 'token_no_valido';
    await app.inject({
      method: 'POST', url: '/sincronizar', headers: ana.headers,
      payload: { categorias: [{ id: 'c1', nombre: 'Nevera', creado: 1, modificado: 1 }] },
    });
    await esperar();
    expect(obtenerBd().prepare('SELECT 1 FROM dispositivos WHERE token = ?').get(TOKEN_LUIS)).toBeUndefined();
  });

  it('quien se une, con su nombre', async () => {
    const ana = persona('Ana', 'ana');
    await app.inject({ method: 'POST', url: '/hogar', headers: ana.headers, payload: { nombre: 'Casa' } });
    await app.inject({ method: 'PUT', url: '/cuenta/avisos', headers: ana.headers, payload: { personasNuevas: true } });
    await app.inject({ method: 'PUT', url: '/dispositivos', headers: ana.headers, payload: { token: TOKEN_ANA, plataforma: 'ios', entorno: 'produccion' } });
    const { codigo } = (await app.inject({ method: 'POST', url: '/hogar/invitaciones', headers: ana.headers })).json();
    const eva = persona('Eva', 'eva');
    await app.inject({ method: 'POST', url: '/hogar/unirse', headers: eva.headers, payload: { codigo } });
    await esperar();
    expect(enviador.enviadas.map((e) => [e.token, e.n.cuerpo])).toEqual([[TOKEN_ANA, 'Eva se ha unido al hogar']]);
  });
});

describe('respuestas de Apple', () => {
  it('interpretar', () => {
    expect(interpretar(200, '')).toBe('enviada');
    expect(interpretar(410, '{"reason":"Unregistered"}')).toBe('token_no_valido');
    expect(interpretar(400, '{"reason":"BadDeviceToken"}')).toBe('token_no_valido');
    expect(interpretar(403, '{"reason":"InvalidProviderToken"}')).toBe('fallo');
    expect(interpretar(500, 'no es json')).toBe('fallo');
  });
});
