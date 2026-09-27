import Fastify, { FastifyInstance } from 'fastify';
import { beforeAll, describe, expect, it } from 'vitest';
import { codigoDelEnlace, registrarRutasEnlaces } from '../enlaces/rutas';

let app: FastifyInstance;

beforeAll(async () => {
  app = Fastify();
  await app.register(registrarRutasEnlaces);
});

describe('enlaces de invitación', () => {
  it('apple-app-site-association: JSON con la app y la ruta /unirse/*', async () => {
    const res = await app.inject({ method: 'GET', url: '/.well-known/apple-app-site-association' });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('application/json');
    const detalle = res.json().applinks.details[0];
    expect(detalle.appIDs).toEqual(['S92QZXCW54.com.jmortiz.inventario']);
    expect(detalle.components).toEqual([{ '/': '/unirse/*' }]);
  });

  it('la página enseña el código en mayúsculas', async () => {
    const res = await app.inject({ method: 'GET', url: '/unirse/k7px3mqa' });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.body).toContain('<html lang="es">');
    expect(res.body).toContain('<h1>Te han invitado a un hogar</h1>');
    expect(res.body).toContain('K7PX3MQA');
  });

  it('lo que no es un código no llega a la página', async () => {
    const res = await app.inject({ method: 'GET', url: '/unirse/%3Cscript%3Ealert(1)%3C%2Fscript%3E' });
    expect(res.statusCode).toBe(200);
    expect(res.body).not.toContain('<script>');
    expect(res.body).not.toContain('Unirme con un código');
  });

  it('codigoDelEnlace', () => {
    expect(codigoDelEnlace('abc123')).toBe('ABC123');
    expect(codigoDelEnlace('')).toBeUndefined();
    expect(codigoDelEnlace('a'.repeat(17))).toBeUndefined();
    expect(codigoDelEnlace('ÑAÑA')).toBeUndefined();
  });
});
