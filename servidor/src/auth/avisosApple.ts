import { borrarCuenta } from '../cuenta/almacen';
import { OpcionesVerificacion, verificarFirmaDeApple } from './appleNativo';
import { revocarTodasLasSesiones } from './sesiones';
import { buscarUsuarioPorProveedor } from './usuarios';

// Avisos que manda Apple cuando alguien cambia su cuenta de Apple (ver CONTRATO-API.md,
// POST /auth/apple/avisos).

export interface AvisoDeApple {
  tipo: string;
  sub: string;
}

export type ResultadoAviso = { valido: true; aviso: AvisoDeApple } | { valido: false; motivo: string };

export async function leerAvisoDeApple(
  payload: string,
  opciones: OpcionesVerificacion,
): Promise<ResultadoAviso> {
  const firma = await verificarFirmaDeApple(payload, opciones);
  if (!firma.valido) return firma;

  // La documentación lo enseña como objeto, pero hay quien lo ha recibido como JSON en texto. Sin
  // haber visto uno de verdad, se aceptan los dos.
  let eventos = firma.cuerpo.events;
  if (typeof eventos === 'string') {
    try {
      eventos = JSON.parse(eventos);
    } catch {
      return { valido: false, motivo: 'el aviso no se puede leer' };
    }
  }
  const { type, sub } = (eventos ?? {}) as { type?: unknown; sub?: unknown };
  if (typeof type !== 'string' || typeof sub !== 'string' || sub.length === 0) {
    return { valido: false, motivo: 'el aviso no dice qué pasó ni a quién' };
  }
  return { valido: true, aviso: { tipo: type, sub } };
}

export type Consecuencia = 'cuenta_borrada' | 'sesiones_cerradas' | 'nada';

export function atenderAvisoDeApple(aviso: AvisoDeApple): Consecuencia {
  const usuarioId = buscarUsuarioPorProveedor('apple', aviso.sub);
  if (usuarioId === undefined) return 'nada';
  switch (aviso.tipo) {
    // «account-deleted» es el nombre de la documentación actual; «account-delete», el de la
    // anterior. No está claro cuál manda Apple de verdad.
    case 'account-deleted':
    case 'account-delete':
      // Sin revocar en Apple: la cuenta de Apple ya no existe y Apple invalida sus tokens.
      borrarCuenta(usuarioId);
      return 'cuenta_borrada';
    case 'consent-revoked':
      revocarTodasLasSesiones(usuarioId);
      return 'sesiones_cerradas';
    default:
      // email-enabled y email-disabled: el servidor no manda correos.
      return 'nada';
  }
}
