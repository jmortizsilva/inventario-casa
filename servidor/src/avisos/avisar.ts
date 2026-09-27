import type { FastifyBaseLogger } from 'fastify';
import { obtenerBd } from '../db';
import type { Sucesos } from '../sincronizacion/almacen';
import { destinatarios, olvidarToken, type TipoAviso } from './almacen';
import type { Enviador } from './apns';
import * as textos from './textos';

// Decide qué notificaciones salen de un cambio y las manda. No se espera a que Apple conteste
// para responder al móvil que hizo el cambio: quien llama no hace await.

// El que se usa en marcha; sin clave de APNs no hay ninguno y no se avisa. Las pruebas ponen
// uno de mentira.
let enviadorActual: Enviador | undefined;
export function usarEnviador(enviador: Enviador | undefined): void {
  enviadorActual = enviador;
}

/** Sin esperar: quien hizo el cambio no tiene que esperar a Apple. */
export function avisarSinEsperar(hogarId: string, quienHizo: number, avisos: Aviso[], registro?: FastifyBaseLogger): void {
  avisar(enviadorActual, hogarId, quienHizo, avisos, registro).catch((error) =>
    registro?.error({ error }, 'fallo al avisar'),
  );
}

export interface Aviso {
  tipo: TipoAviso;
  cuerpo: string;
}

/** Una por tipo, solo de lo que ha pasado. */
export function avisosDeSucesos(nombre: string | null, s: Sucesos): Aviso[] {
  const quien = nombre ?? 'Alguien';
  const avisos: Aviso[] = [];
  if (s.productosNuevos.length) avisos.push({ tipo: 'productosNuevos', cuerpo: textos.productosNuevos(quien, s.productosNuevos) });
  if (s.categoriasNuevas.length) avisos.push({ tipo: 'categoriasNuevas', cuerpo: textos.categoriasNuevas(quien, s.categoriasNuevas) });
  if (s.entranEnLista.length) avisos.push({ tipo: 'entraEnLista', cuerpo: textos.entranEnLista(s.entranEnLista) });
  if (s.salenDeLista.length) avisos.push({ tipo: 'saleDeLista', cuerpo: textos.salenDeLista(s.salenDeLista) });
  return avisos;
}

export async function avisar(
  enviador: Enviador | undefined,
  hogarId: string,
  quienHizo: number,
  avisos: Aviso[],
  registro?: FastifyBaseLogger,
): Promise<void> {
  if (!enviador || avisos.length === 0) return;
  const hogar = obtenerBd().prepare('SELECT nombre FROM hogares WHERE id = ?').get(hogarId) as
    | { nombre: string }
    | undefined;
  if (!hogar) return;
  for (const aviso of avisos) {
    for (const d of destinatarios(hogarId, quienHizo, aviso.tipo)) {
      if (d.plataforma !== 'ios') continue; // Android, cuando exista, irá por FCM.
      const resultado = await enviador.enviar(d.token, d.entorno, {
        titulo: hogar.nombre,
        cuerpo: aviso.cuerpo,
        hilo: hogarId,
      });
      if (resultado === 'token_no_valido') olvidarToken(d.token);
      if (resultado === 'fallo') registro?.warn({ tipo: aviso.tipo }, 'no se pudo enviar una notificación');
    }
  }
}

/** El nombre de quien hizo el cambio, o null si no tiene (Apple no lo da). */
export function nombreDe(usuarioId: number): string | null {
  const fila = obtenerBd().prepare('SELECT nombre FROM usuarios WHERE id = ?').get(usuarioId) as
    | { nombre: string | null }
    | undefined;
  return fila?.nombre ?? null;
}
