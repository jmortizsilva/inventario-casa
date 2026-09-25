import Fastify, { FastifyInstance } from 'fastify';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

let app: FastifyInstance;
let inicializarBd: (typeof import('../db'))['inicializarBd'];
let obtenerOCrearUsuario: (typeof import('../auth/usuarios'))['obtenerOCrearUsuario'];
let iniciarSesion: (typeof import('../auth/sesiones'))['iniciarSesion'];
let crearHogar: (typeof import('../hogares/almacen'))['crearHogar'];

beforeAll(async () => {
  process.env.INVENTARIO_TOKEN_SECRET = 'secreto-de-prueba';
  ({ inicializarBd } = await import('../db'));
  ({ obtenerOCrearUsuario } = await import('../auth/usuarios'));
  ({ iniciarSesion } = await import('../auth/sesiones'));
  ({ crearHogar } = await import('../hogares/almacen'));
  const { registrarRutasSincronizacion } = await import('../sincronizacion/rutas');
  app = Fastify();
  await app.register(registrarRutasSincronizacion);
});

beforeEach(() => {
  inicializarBd(':memory:');
});

function cabecera(nombre: string, conHogar = true) {
  const usuario = obtenerOCrearUsuario({
    proveedor: 'google',
    idProveedor: `sub-${nombre}`,
    email: `${nombre}@ejemplo.com`,
    nombre,
    emailVerificado: true,
  })!;
  if (conHogar) crearHogar(usuario.id, 'Casa');
  return { authorization: `Bearer ${iniciarSesion(usuario.id, null).tokenAcceso}` };
}

describe('/sincronizar', () => {
  it('sin sesión: 401; sin hogar: 409', async () => {
    expect((await app.inject({ method: 'GET', url: '/sincronizar' })).statusCode).toBe(401);
    const sinHogar = cabecera('eva', false);
    expect((await app.inject({ method: 'GET', url: '/sincronizar', headers: sinHogar })).statusCode).toBe(409);
    expect((await app.inject({ method: 'POST', url: '/sincronizar', headers: sinHogar, payload: {} })).statusCode).toBe(409);
  });

  it('enviar y recibir', async () => {
    const ana = cabecera('ana');
    const envio = await app.inject({
      method: 'POST',
      url: '/sincronizar',
      headers: ana,
      payload: {
        categorias: [{ id: 'c1', nombre: 'Despensa', creado: 1, modificado: 1 }],
        productos: [
          {
            id: 'p1', categoriaId: 'c1', nombre: 'Arroz', umbralCompra: 2, autoListaCompra: true,
            enListaCompraManual: false, creado: 1, modificado: 1, cantidad: 4, cantidadFijadaEn: 1,
          },
        ],
        movimientos: [{ id: 'm1', productoId: 'p1', cambio: -1, momento: 5 }],
      },
    });
    expect(envio.statusCode).toBe(200);
    expect(envio.json().productos[0].cantidad).toBe(3);

    const recibido = await app.inject({ method: 'GET', url: '/sincronizar?desde=0', headers: ana });
    expect(recibido.json()).toMatchObject({
      categorias: [{ id: 'c1' }],
      productos: [{ id: 'p1', cantidad: 3 }],
      masDisponible: false,
    });
  });

  it('parámetros no válidos: 400', async () => {
    const ana = cabecera('ana');
    const res = await app.inject({ method: 'GET', url: '/sincronizar?desde=-3', headers: ana });
    expect(res.statusCode).toBe(400);
  });

  it('lote de más de 1000: 413', async () => {
    const ana = cabecera('ana');
    const categorias = Array.from({ length: 1001 }, (_, i) => ({ id: `c${i}`, nombre: 'X', creado: 1, modificado: 1 }));
    const res = await app.inject({ method: 'POST', url: '/sincronizar', headers: ana, payload: { categorias } });
    expect(res.statusCode).toBe(413);
  });
});
