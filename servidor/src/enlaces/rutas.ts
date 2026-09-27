import { FastifyInstance } from 'fastify';

// El enlace de las invitaciones, https://inventario.jmortiz.es/unirse/<código> (ver
// CONTRATO-API.md). Con la app instalada lo abre la app; sin ella, esta página.

// Quién puede abrir los enlaces de este dominio. Apple lo pide sin redirecciones y como JSON.
// Android pedirá su /.well-known/assetlinks.json con la misma ruta /unirse/*.
const ASOCIACION_APPLE = {
  applinks: {
    details: [
      {
        appIDs: ['S92QZXCW54.com.jmortiz.inventario'],
        components: [{ '/': '/unirse/*' }],
      },
    ],
  },
};

// Solo letras y números, como en la app: lo demás no puede ser un código, y así nada del
// enlace llega a la página sin limpiar.
export function codigoDelEnlace(texto: string): string | undefined {
  const codigo = texto.toUpperCase();
  return /^[A-Z0-9]{1,16}$/.test(codigo) ? codigo : undefined;
}

// No comprueba si el código vale: si lo hiciera, cualquiera podría probar códigos a ciegas
// desde la web, sin el límite de intentos de /hogar/unirse.
export function paginaInvitacion(codigo: string | undefined): string {
  const conCodigo = codigo
    ? `<p>O escribe este código en la app, en Ajustes, Unirme con un código:</p>
<p class="codigo">${codigo}</p>
<p>El código sirve una vez y caduca a los 7 días.</p>`
    : '';
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Invitación a Inventario Casa</title>
<style>
body { font-family: -apple-system, system-ui, sans-serif; max-width: 32rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
.codigo { font-size: 2rem; font-weight: bold; letter-spacing: 0.1em; }
</style>
</head>
<body>
<h1>Te han invitado a un hogar</h1>
<p>Abre este enlace en el móvil donde tengas Inventario Casa y se abrirá la invitación.</p>
${conCodigo}
</body>
</html>
`;
}

export async function registrarRutasEnlaces(app: FastifyInstance): Promise<void> {
  app.get('/.well-known/apple-app-site-association', async (_request, reply) => {
    return reply.type('application/json').send(ASOCIACION_APPLE);
  });

  app.get<{ Params: { codigo: string } }>('/unirse/:codigo', async (request, reply) => {
    return reply.type('text/html; charset=utf-8').send(paginaInvitacion(codigoDelEnlace(request.params.codigo)));
  });
}
