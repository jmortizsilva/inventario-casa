import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { crearHogar, crearInvitacion, hogarDeUsuario, limpiarNombre, salir, unirse } from './almacen';

// Rutas de /hogar (ver CONTRATO-API.md). El hogar de cada persona sale siempre de la tabla de
// miembros del servidor: ninguna ruta acepta un id de hogar del móvil.
export async function registrarRutasHogar(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  app.get('/hogar', { preHandler: exigirSesion }, async (request) => ({
    hogar: hogarDeUsuario(request.usuarioId!) ?? null,
  }));

  app.post<{ Body: { nombre?: unknown } }>('/hogar', { preHandler: exigirSesion }, async (request, reply) => {
    const nombre = limpiarNombre(request.body?.nombre);
    if (!nombre) {
      return reply.code(400).send({ error: 'nombre vacío o de más de 100 letras' });
    }
    const resultado = crearHogar(request.usuarioId!, nombre);
    if ('error' in resultado) {
      return reply.code(409).send({ error: 'ya estás en un hogar' });
    }
    return reply.code(201).send(resultado);
  });

  app.post('/hogar/invitaciones', { preHandler: exigirSesion }, async (request, reply) => {
    const resultado = crearInvitacion(request.usuarioId!);
    if ('error' in resultado) {
      return reply.code(409).send({ error: 'no estás en ningún hogar' });
    }
    return reply.code(201).send(resultado);
  });

  app.post<{ Body: { codigo?: unknown } }>(
    '/hogar/unirse',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const resultado = unirse(request.usuarioId!, request.body?.codigo);
      if ('hogar' in resultado) return resultado;
      switch (resultado.error) {
        case 'demasiados_intentos':
          return reply.code(429).send({ error: 'demasiados intentos, prueba dentro de una hora' });
        case 'ya_en_un_hogar':
          return reply.code(409).send({ error: 'ya estás en un hogar' });
        case 'codigo_no_valido':
          // Igual para inexistente, caducado o usado: no dar pistas a quien pruebe códigos.
          return reply.code(404).send({ error: 'código no válido' });
      }
    },
  );

  app.post('/hogar/salir', { preHandler: exigirSesion }, async (request, reply) => {
    const resultado = salir(request.usuarioId!);
    if ('error' in resultado) {
      return reply.code(409).send({ error: 'no estás en ningún hogar' });
    }
    return resultado;
  });
}
