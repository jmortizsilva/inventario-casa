import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { hogarDeMiembro, hogarDeUsuario } from '../hogares/almacen';
import { cambiarPreferencias, preferencias, quitarDispositivo, registrarDispositivo, TIPOS, type Preferencias } from './almacen';

// Rutas de notificaciones (ver CONTRATO-API.md).
export async function registrarRutasAvisos(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  // Qué cambiar, o el error. Solo booleanos, y solo los que vienen.
  function leerCambios(cuerpo: Record<string, unknown>): Partial<Preferencias> | string {
    const cambios: Partial<Preferencias> = {};
    for (const tipo of TIPOS) {
      if (!(tipo in cuerpo)) continue;
      if (typeof cuerpo[tipo] !== 'boolean') return `"${tipo}" tiene que ser true o false`;
      cambios[tipo] = cuerpo[tipo] as boolean;
    }
    return cambios;
  }

  // Las de un solo hogar: las del primero. Sin hogar, todas desactivadas y nada que cambiar.
  app.get('/cuenta/avisos', { preHandler: exigirSesion }, async (request) => {
    const hogar = hogarDeUsuario(request.usuarioId!);
    return hogar ? preferencias(request.usuarioId!, hogar.id) : preferencias(request.usuarioId!, '');
  });

  app.put<{ Body: Record<string, unknown> | undefined }>(
    '/cuenta/avisos',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const cambios = leerCambios(request.body ?? {});
      if (typeof cambios === 'string') return reply.code(400).send({ error: cambios });
      const hogar = hogarDeUsuario(request.usuarioId!);
      if (!hogar) return reply.code(409).send({ error: 'no estás en ningún hogar' });
      return cambiarPreferencias(request.usuarioId!, hogar.id, cambios);
    },
  );

  app.get<{ Params: { id: string } }>('/hogares/:id/avisos', { preHandler: exigirSesion }, async (request, reply) => {
    const hogar = hogarDeMiembro(request.usuarioId!, request.params.id);
    if (!hogar) return reply.code(404).send({ error: 'hogar no encontrado' });
    return preferencias(request.usuarioId!, hogar.id);
  });

  app.put<{ Params: { id: string }; Body: Record<string, unknown> | undefined }>(
    '/hogares/:id/avisos',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const hogar = hogarDeMiembro(request.usuarioId!, request.params.id);
      if (!hogar) return reply.code(404).send({ error: 'hogar no encontrado' });
      const cambios = leerCambios(request.body ?? {});
      if (typeof cambios === 'string') return reply.code(400).send({ error: cambios });
      return cambiarPreferencias(request.usuarioId!, hogar.id, cambios);
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
