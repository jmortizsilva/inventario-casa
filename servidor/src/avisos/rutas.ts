import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { cambiarPreferencias, preferencias, quitarDispositivo, registrarDispositivo, TIPOS, type Preferencias } from './almacen';

// Rutas de notificaciones (ver CONTRATO-API.md).
export async function registrarRutasAvisos(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  app.get('/cuenta/avisos', { preHandler: exigirSesion }, async (request) => preferencias(request.usuarioId!));

  app.put<{ Body: Record<string, unknown> | undefined }>(
    '/cuenta/avisos',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const cuerpo = request.body ?? {};
      const cambios: Partial<Preferencias> = {};
      for (const tipo of TIPOS) {
        if (!(tipo in cuerpo)) continue;
        if (typeof cuerpo[tipo] !== 'boolean') return reply.code(400).send({ error: `"${tipo}" tiene que ser true o false` });
        cambios[tipo] = cuerpo[tipo] as boolean;
      }
      return cambiarPreferencias(request.usuarioId!, cambios);
    },
  );

  app.put<{ Body: { token?: unknown; plataforma?: unknown; entorno?: unknown } | undefined }>(
    '/dispositivos',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const { token, plataforma, entorno } = request.body ?? {};
      if (typeof token !== 'string' || !/^[0-9a-fA-F]{32,200}$/.test(token)) {
        return reply.code(400).send({ error: 'falta "token"' });
      }
      if (plataforma !== 'ios') return reply.code(400).send({ error: '"plataforma" no soportada' });
      if (entorno !== 'produccion' && entorno !== 'desarrollo') {
        return reply.code(400).send({ error: '"entorno" tiene que ser produccion o desarrollo' });
      }
      registrarDispositivo(request.usuarioId!, { token: token.toLowerCase(), plataforma, entorno });
      return { ok: true };
    },
  );

  app.delete<{ Params: { token: string } }>('/dispositivos/:token', { preHandler: exigirSesion }, async (request) => {
    quitarDispositivo(request.usuarioId!, request.params.token.toLowerCase());
    return { ok: true };
  });
}
