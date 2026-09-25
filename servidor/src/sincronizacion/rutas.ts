import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { hogarDeUsuario } from '../hogares/almacen';
import { Lote, aplicarLote, novedadesDesde } from './almacen';

const LIMITE_POR_DEFECTO = 500;
const LIMITE_MAXIMO = 1000;

// El hogar sale siempre de la tabla de miembros: el móvil nunca dice en qué hogar escribe.
export async function registrarRutasSincronizacion(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  app.get<{ Querystring: { desde?: string; limite?: string } }>(
    '/sincronizar',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const hogar = hogarDeUsuario(request.usuarioId!);
      if (!hogar) return reply.code(409).send({ error: 'no estás en ningún hogar' });
      const desde = Number(request.query.desde ?? 0);
      const limite = Number(request.query.limite ?? LIMITE_POR_DEFECTO);
      if (!Number.isSafeInteger(desde) || desde < 0 || !Number.isSafeInteger(limite) || limite < 1) {
        return reply.code(400).send({ error: '"desde" y "limite" tienen que ser enteros positivos' });
      }
      return novedadesDesde(hogar.id, desde, Math.min(limite, LIMITE_MAXIMO));
    },
  );

  app.post<{ Body: Lote }>('/sincronizar', { preHandler: exigirSesion }, async (request, reply) => {
    const hogar = hogarDeUsuario(request.usuarioId!);
    if (!hogar) return reply.code(409).send({ error: 'no estás en ningún hogar' });
    const resultado = aplicarLote(hogar.id, request.body ?? {});
    if ('error' in resultado) {
      return reply.code(413).send({ error: `como mucho ${LIMITE_MAXIMO} cambios por lote` });
    }
    return resultado;
  });
}
