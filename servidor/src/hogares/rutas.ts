import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { avisarSinEsperar, nombreDe } from '../avisos/avisar';
import { personaNueva } from '../avisos/textos';
import {
  crearHogar,
  crearInvitacion,
  hogarDeMiembro,
  hogarDeUsuario,
  hogaresDeUsuario,
  limpiarNombre,
  type Modo,
  salir,
  unirse,
} from './almacen';

// Rutas de hogares (ver CONTRATO-API.md). La pertenencia sale siempre de la tabla de miembros
// del servidor: el móvil dice de qué hogar habla, pero si no está en él recibe un 404, igual que
// si no existiera.
//
// /hogar… son las de un solo hogar, para las compilaciones que no saben llevar varios: trabajan
// sobre el primero y no dejan crear ni unirse a otro. /hogares… son las de varios.
export async function registrarRutasHogar(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  // MARK: Un solo hogar

  app.get('/hogar', { preHandler: exigirSesion }, async (request) => ({
    hogar: hogarDeUsuario(request.usuarioId!) ?? null,
  }));

  app.post<{ Body: { nombre?: unknown } }>('/hogar', { preHandler: exigirSesion }, async (request, reply) =>
    crear(request, reply, 'unico'),
  );

  app.post('/hogar/invitaciones', { preHandler: exigirSesion }, async (request, reply) => {
    const resultado = crearInvitacion(request.usuarioId!);
    if ('error' in resultado) {
      return reply.code(409).send({ error: 'no estás en ningún hogar' });
    }
    return reply.code(201).send(resultado);
  });

  app.post<{ Body: { codigo?: unknown } }>('/hogar/unirse', { preHandler: exigirSesion }, async (request, reply) =>
    unirseCon(request, reply, 'unico'),
  );

  app.post('/hogar/salir', { preHandler: exigirSesion }, async (request, reply) => {
    const resultado = salir(request.usuarioId!);
    if ('error' in resultado) {
      return reply.code(409).send({ error: 'no estás en ningún hogar' });
    }
    return resultado;
  });

  // MARK: Varios hogares

  app.get('/hogares', { preHandler: exigirSesion }, async (request) => ({
    hogares: hogaresDeUsuario(request.usuarioId!),
  }));

  app.post<{ Body: { nombre?: unknown } }>('/hogares', { preHandler: exigirSesion }, async (request, reply) =>
    crear(request, reply, 'varios'),
  );

  app.post<{ Body: { codigo?: unknown } }>('/hogares/unirse', { preHandler: exigirSesion }, async (request, reply) =>
    unirseCon(request, reply, 'varios'),
  );

  app.post<{ Params: { id: string } }>(
    '/hogares/:id/invitaciones',
    { preHandler: exigirSesion },
    async (request, reply) => {
      const resultado = crearInvitacion(request.usuarioId!, undefined, undefined, request.params.id);
      if ('error' in resultado) return reply.code(404).send({ error: 'hogar no encontrado' });
      return reply.code(201).send(resultado);
    },
  );

  app.post<{ Params: { id: string } }>('/hogares/:id/salir', { preHandler: exigirSesion }, async (request, reply) => {
    if (!hogarDeMiembro(request.usuarioId!, request.params.id)) {
      return reply.code(404).send({ error: 'hogar no encontrado' });
    }
    return salir(request.usuarioId!, undefined, request.params.id);
  });

  // MARK: Comunes

  async function crear(
    request: FastifyRequest<{ Body: { nombre?: unknown } }>,
    reply: FastifyReply,
    modo: Modo,
  ): Promise<FastifyReply> {
    const nombre = limpiarNombre(request.body?.nombre);
    if (!nombre) {
      return reply.code(400).send({ error: 'nombre vacío o de más de 100 letras' });
    }
    const resultado = crearHogar(request.usuarioId!, nombre, undefined, modo);
    if ('error' in resultado) {
      return reply
        .code(409)
        .send({ error: resultado.error === 'limite_hogares' ? 'limite_hogares' : 'ya estás en un hogar' });
    }
    return reply.code(201).send(resultado);
  }

  async function unirseCon(
    request: FastifyRequest<{ Body: { codigo?: unknown } }>,
    reply: FastifyReply,
    modo: Modo,
  ): Promise<FastifyReply> {
    const resultado = unirse(request.usuarioId!, request.body?.codigo, undefined, modo);
    if ('hogar' in resultado) {
      const quien = request.usuarioId!;
      avisarSinEsperar(
        resultado.hogar.id,
        quien,
        [{ tipo: 'personasNuevas', cuerpo: personaNueva(nombreDe(quien)) }],
        request.log,
      );
      return reply.send(resultado);
    }
    switch (resultado.error) {
      case 'demasiados_intentos':
        return reply.code(429).send({ error: 'demasiados intentos, prueba dentro de una hora' });
      case 'ya_en_un_hogar':
        return reply.code(409).send({ error: 'ya estás en un hogar' });
      case 'ya_en_este_hogar':
      case 'limite_hogares':
        return reply.code(409).send({ error: resultado.error });
      case 'codigo_no_valido':
        // Igual para inexistente, caducado o usado: no dar pistas a quien pruebe códigos.
        return reply.code(404).send({ error: 'código no válido' });
    }
  }
}
