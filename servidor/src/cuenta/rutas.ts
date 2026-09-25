import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { crearExigirSesion } from '../auth/middleware';
import { obtenerUsuarioPorId } from '../auth/usuarios';
import { borrarCuenta } from './almacen';
import { revocarAccesoApple } from './revocarApple';

// Rutas de /cuenta (ver CONTRATO-API.md).
export async function registrarRutasCuenta(app: FastifyInstance): Promise<void> {
  const exigirSesion = crearExigirSesion(config.tokenSecreto ?? '');

  app.delete<{ Body: { codigoApple?: unknown } | undefined }>(
    '/cuenta',
    { preHandler: exigirSesion, config: { rateLimit: { max: 10, timeWindow: '15 minutes' } } },
    async (request, reply) => {
      const usuario = obtenerUsuarioPorId(request.usuarioId!)!;

      // En Apple se revoca antes de borrar: si falla, la cuenta sigue y la app puede reintentar.
      // Al revés, quedaría borrada aquí y con acceso en Apple, sin forma de volver a intentarlo.
      if (usuario.proveedor === 'apple') {
        const codigo = request.body?.codigoApple;
        if (typeof codigo !== 'string' || codigo.length === 0) {
          return reply.code(400).send({ error: 'falta_codigo_apple' });
        }
        const resultado = await revocarAccesoApple(codigo);
        if (resultado === 'codigo_no_valido') {
          return reply.code(400).send({ error: 'codigo_apple_no_valido' });
        }
        if (resultado === 'fallo_apple') {
          request.log.error('no se pudo revocar el acceso en Apple al borrar una cuenta');
          return reply.code(502).send({ error: 'no se pudo hablar con Apple' });
        }
      }

      borrarCuenta(usuario.id);
      return { ok: true };
    },
  );
}
