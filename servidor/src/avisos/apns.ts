import { connect, constants, type ClientHttp2Session } from 'node:http2';
import { config } from '../config';
import { firmarJwtEs256 } from '../auth/jwtEs256';
import type { Entorno } from './almacen';

// Envío a APNs sin librerías: HTTP/2 de Node y el mismo firmado ES256 que el client_secret de
// Sign in with Apple. Detalles del protocolo en la documentación de Apple, «Sending notification
// requests to APNs».

export interface Notificacion {
  titulo: string;
  cuerpo: string;
  /** Agrupa en el centro de notificaciones las del mismo hogar. */
  hilo: string;
}

export type ResultadoEnvio = 'enviada' | 'token_no_valido' | 'fallo';

export interface Enviador {
  enviar(token: string, entorno: Entorno, notificacion: Notificacion): Promise<ResultadoEnvio>;
}

const SERVIDORES: Record<Entorno, string> = {
  produccion: 'https://api.push.apple.com',
  desarrollo: 'https://api.sandbox.push.apple.com',
};

// Apple rechaza un token de proveedor de más de una hora y pide no firmar uno nuevo más de una
// vez cada 20 minutos: se reutiliza durante 40.
const VIDA_TOKEN_MS = 40 * 60 * 1000;

export class EnviadorApns implements Enviador {
  private token: { valor: string; hasta: number } | undefined;
  private sesiones = new Map<Entorno, ClientHttp2Session>();

  constructor(private readonly ahora: () => number = () => Date.now()) {}

  static configurado(): boolean {
    return Boolean(config.apns.keyId && config.apns.privateKey && config.apple.teamId);
  }

  private tokenProveedor(): string {
    if (this.token && this.token.hasta > this.ahora()) return this.token.valor;
    const valor = firmarJwtEs256(
      { iss: config.apple.teamId, iat: Math.floor(this.ahora() / 1000) },
      config.apns.keyId ?? '',
      config.apns.privateKey ?? '',
    );
    this.token = { valor, hasta: this.ahora() + VIDA_TOKEN_MS };
    return valor;
  }

  private sesion(entorno: Entorno): ClientHttp2Session {
    const abierta = this.sesiones.get(entorno);
    if (abierta && !abierta.closed && !abierta.destroyed) return abierta;
    const nueva = connect(SERVIDORES[entorno]);
    nueva.on('error', () => this.sesiones.delete(entorno));
    nueva.on('close', () => this.sesiones.delete(entorno));
    this.sesiones.set(entorno, nueva);
    return nueva;
  }

  enviar(token: string, entorno: Entorno, n: Notificacion): Promise<ResultadoEnvio> {
    const cuerpo = JSON.stringify({
      aps: { alert: { title: n.titulo, body: n.cuerpo }, sound: 'default', 'thread-id': n.hilo },
    });
    return new Promise((resolver) => {
      let peticion;
      try {
        peticion = this.sesion(entorno).request({
          [constants.HTTP2_HEADER_METHOD]: 'POST',
          [constants.HTTP2_HEADER_PATH]: `/3/device/${token}`,
          authorization: `bearer ${this.tokenProveedor()}`,
          'apns-topic': config.apns.topic,
          'apns-push-type': 'alert',
          'apns-priority': '10',
        });
      } catch {
        resolver('fallo');
        return;
      }
      let estado = 0;
      let respuesta = '';
      peticion.on('response', (cabeceras) => {
        estado = Number(cabeceras[constants.HTTP2_HEADER_STATUS]);
      });
      peticion.on('data', (trozo) => (respuesta += trozo));
      peticion.on('end', () => resolver(interpretar(estado, respuesta)));
      peticion.on('error', () => resolver('fallo'));
      peticion.setTimeout(10_000, () => {
        peticion.close();
        resolver('fallo');
      });
      peticion.end(cuerpo);
    });
  }
}

/** 410 es que la app se desinstaló; BadDeviceToken, un token que no es de este entorno o no existe. */
export function interpretar(estado: number, respuesta: string): ResultadoEnvio {
  if (estado === 200) return 'enviada';
  if (estado === 410) return 'token_no_valido';
  let motivo = '';
  try {
    motivo = (JSON.parse(respuesta) as { reason?: string }).reason ?? '';
  } catch {
    // Sin cuerpo legible: se trata como fallo.
  }
  return motivo === 'BadDeviceToken' || motivo === 'Unregistered' ? 'token_no_valido' : 'fallo';
}
