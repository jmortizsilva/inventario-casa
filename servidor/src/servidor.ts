import formbody from '@fastify/formbody';
import rateLimit from '@fastify/rate-limit';
import Fastify, { FastifyInstance } from 'fastify';
import { registrarRutasAuth } from './auth/rutas';
import { registrarRutasCuenta } from './cuenta/rutas';
import { registrarRutasHogar } from './hogares/rutas';
import { registrarRutasSincronizacion } from './sincronizacion/rutas';

export async function crearServidor(): Promise<FastifyInstance> {
  const app = Fastify({ logger: true, bodyLimit: 1_000_000 });

  // Límite general de abuso; algunas rutas llevan además el suyo, más estricto.
  await app.register(rateLimit, { max: 120, timeWindow: '1 minute' });

  // Apple manda la vuelta del inicio de sesión por POST con application/x-www-form-urlencoded.
  await app.register(formbody);

  app.get('/', async () => ({ ok: true, servicio: 'inventario-casa' }));

  await app.register(registrarRutasAuth);
  await app.register(registrarRutasCuenta);
  await app.register(registrarRutasHogar);
  await app.register(registrarRutasSincronizacion);

  return app;
}
