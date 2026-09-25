import { randomInt, randomUUID } from 'node:crypto';
import { obtenerBd } from '../db';

// Hogares, miembros e invitaciones. Todo lo que decide recibe el reloj (`ahora`) y, las
// invitaciones, el generador de códigos, para poder probarlo sin esperas ni azar.

export const LARGO_MAXIMO_NOMBRE = 100;
export const DURACION_INVITACION_MS = 7 * 24 * 60 * 60 * 1000;
export const INTENTOS_FALLIDOS_POR_HORA = 10;
export const DIAS_HASTA_BORRAR_HOGAR_VACIO = 30;

const UNA_HORA_MS = 60 * 60 * 1000;
const UN_DIA_MS = 24 * UNA_HORA_MS;

// Sin 0/O ni 1/I/L, que se confunden al dictarlos o al leerlos en voz alta.
export const ALFABETO_CODIGO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const LARGO_CODIGO = 8;

type Reloj = () => number;
const relojReal: Reloj = () => Date.now();

export interface Miembro {
  id: number;
  nombre: string | null;
  email: string;
}

export interface Hogar {
  id: string;
  nombre: string;
  miembros: Miembro[];
  revision: number;
}

interface FilaHogar {
  id: string;
  nombre: string;
  revision: number;
}

// Quita espacios de los extremos y deja uno solo entre palabras, como `Nombres.limpiar` en la app.
export function limpiarNombre(texto: unknown): string | undefined {
  if (typeof texto !== 'string') return undefined;
  const limpio = texto.split(/\s+/).filter((parte) => parte.length > 0).join(' ');
  if (limpio.length === 0 || [...limpio].length > LARGO_MAXIMO_NOMBRE) return undefined;
  return limpio;
}

export function hogarDeUsuario(usuarioId: number): Hogar | undefined {
  const bd = obtenerBd();
  const fila = bd
    .prepare(
      `SELECT h.id, h.nombre, h.revision FROM hogares h
       JOIN miembros m ON m.hogar_id = h.id WHERE m.usuario_id = ?`,
    )
    .get(usuarioId) as FilaHogar | undefined;
  if (!fila) return undefined;
  const miembros = bd
    .prepare(
      `SELECT u.id, u.nombre, u.email FROM miembros m JOIN usuarios u ON u.id = m.usuario_id
       WHERE m.hogar_id = ? ORDER BY m.unido_en, u.id`,
    )
    .all(fila.id) as Miembro[];
  return { ...fila, miembros };
}

export type ResultadoCrear = { hogar: Hogar } | { error: 'ya_en_un_hogar' };

export function crearHogar(usuarioId: number, nombre: string, ahora: Reloj = relojReal): ResultadoCrear {
  const bd = obtenerBd();
  return bd.transaction((): ResultadoCrear => {
    if (hogarDeUsuario(usuarioId)) return { error: 'ya_en_un_hogar' };
    const id = randomUUID();
    const momento = ahora();
    bd.prepare('INSERT INTO hogares (id, nombre, creado_en) VALUES (?, ?, ?)').run(id, nombre, momento);
    bd.prepare('INSERT INTO miembros (usuario_id, hogar_id, unido_en) VALUES (?, ?, ?)').run(
      usuarioId,
      id,
      momento,
    );
    return { hogar: hogarDeUsuario(usuarioId)! };
  })();
}

export function generarCodigo(aleatorio: (maximo: number) => number = randomInt): string {
  let codigo = '';
  for (let i = 0; i < LARGO_CODIGO; i++) {
    codigo += ALFABETO_CODIGO[aleatorio(ALFABETO_CODIGO.length)];
  }
  return codigo;
}

export type ResultadoInvitacion =
  | { codigo: string; caducaEn: number }
  | { error: 'sin_hogar' };

export function crearInvitacion(
  usuarioId: number,
  ahora: Reloj = relojReal,
  nuevoCodigo: () => string = () => generarCodigo(),
): ResultadoInvitacion {
  const hogar = hogarDeUsuario(usuarioId);
  if (!hogar) return { error: 'sin_hogar' };
  const bd = obtenerBd();
  const momento = ahora();
  const caducaEn = momento + DURACION_INVITACION_MS;
  // Con 31^8 combinaciones una colisión es casi imposible, pero si pasa se prueba otro código
  // en lugar de fallar.
  for (let intento = 0; intento < 5; intento++) {
    const codigo = nuevoCodigo();
    const existe = bd.prepare('SELECT 1 FROM invitaciones WHERE codigo = ?').get(codigo);
    if (existe) continue;
    bd.prepare(
      `INSERT INTO invitaciones (codigo, hogar_id, creada_por, creada_en, caduca_en)
       VALUES (?, ?, ?, ?, ?)`,
    ).run(codigo, hogar.id, usuarioId, momento, caducaEn);
    return { codigo, caducaEn };
  }
  throw new Error('no se pudo generar un código de invitación libre');
}

export type ResultadoUnirse =
  | { hogar: Hogar }
  | { error: 'ya_en_un_hogar' | 'codigo_no_valido' | 'demasiados_intentos' };

export function unirse(usuarioId: number, codigoEscrito: unknown, ahora: Reloj = relojReal): ResultadoUnirse {
  const bd = obtenerBd();
  return bd.transaction((): ResultadoUnirse => {
    const momento = ahora();
    const fallidos = bd
      .prepare('SELECT COUNT(*) AS n FROM intentos_unirse WHERE usuario_id = ? AND momento > ?')
      .get(usuarioId, momento - UNA_HORA_MS) as { n: number };
    if (fallidos.n >= INTENTOS_FALLIDOS_POR_HORA) return { error: 'demasiados_intentos' };
    if (hogarDeUsuario(usuarioId)) return { error: 'ya_en_un_hogar' };

    // Se admite escrito en minúsculas o con espacios, como se dicta.
    const codigo = typeof codigoEscrito === 'string' ? codigoEscrito.replace(/\s+/g, '').toUpperCase() : '';
    const invitacion = bd
      .prepare('SELECT hogar_id FROM invitaciones WHERE codigo = ? AND usada_en IS NULL AND caduca_en > ?')
      .get(codigo, momento) as { hogar_id: string } | undefined;
    // Un hogar que se quedó vacío sigue existiendo 30 días, pero no se puede entrar con una
    // invitación antigua: nadie de dentro lo ha invitado.
    const hogarConGente = invitacion
      ? bd.prepare('SELECT 1 FROM miembros WHERE hogar_id = ?').get(invitacion.hogar_id)
      : undefined;
    if (!invitacion || !hogarConGente) {
      bd.prepare('INSERT INTO intentos_unirse (usuario_id, momento) VALUES (?, ?)').run(usuarioId, momento);
      return { error: 'codigo_no_valido' };
    }

    bd.prepare('UPDATE invitaciones SET usada_en = ?, usada_por = ? WHERE codigo = ?').run(
      momento,
      usuarioId,
      codigo,
    );
    bd.prepare('INSERT INTO miembros (usuario_id, hogar_id, unido_en) VALUES (?, ?, ?)').run(
      usuarioId,
      invitacion.hogar_id,
      momento,
    );
    return { hogar: hogarDeUsuario(usuarioId)! };
  })();
}

export function salir(usuarioId: number, ahora: Reloj = relojReal): { ok: true } | { error: 'sin_hogar' } {
  const bd = obtenerBd();
  return bd.transaction((): { ok: true } | { error: 'sin_hogar' } => {
    const hogar = hogarDeUsuario(usuarioId);
    if (!hogar) return { error: 'sin_hogar' };
    bd.prepare('DELETE FROM miembros WHERE usuario_id = ?').run(usuarioId);
    if (hogar.miembros.length === 1) {
      bd.prepare('UPDATE hogares SET vacio_desde = ? WHERE id = ?').run(ahora(), hogar.id);
    }
    return { ok: true };
  })();
}

// Borra los hogares sin nadie desde hace más de 30 días, con su inventario y sus invitaciones.
// Devuelve cuántos.
export function purgarHogaresVacios(ahora: Reloj = relojReal): number {
  const bd = obtenerBd();
  const limite = ahora() - DIAS_HASTA_BORRAR_HOGAR_VACIO * UN_DIA_MS;
  return bd.transaction(() => {
    const ids = (
      bd
        .prepare(
          `SELECT id FROM hogares WHERE vacio_desde IS NOT NULL AND vacio_desde < ?
           AND NOT EXISTS (SELECT 1 FROM miembros WHERE hogar_id = hogares.id)`,
        )
        .all(limite) as { id: string }[]
    ).map((fila) => fila.id);
    for (const id of ids) {
      bd.prepare(
        'DELETE FROM movimientos WHERE producto_id IN (SELECT id FROM productos WHERE hogar_id = ?)',
      ).run(id);
      bd.prepare('DELETE FROM productos WHERE hogar_id = ?').run(id);
      bd.prepare('DELETE FROM categorias WHERE hogar_id = ?').run(id);
      bd.prepare('DELETE FROM invitaciones WHERE hogar_id = ?').run(id);
      bd.prepare('DELETE FROM hogares WHERE id = ?').run(id);
    }
    return ids.length;
  })();
}
