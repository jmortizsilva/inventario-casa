import { obtenerBd } from '../db';

// Preferencias de notificaciones y dispositivos de cada persona.

export interface Preferencias {
  productosNuevos: boolean;
  categoriasNuevas: boolean;
  entraEnLista: boolean;
  saleDeLista: boolean;
  personasNuevas: boolean;
}

export type TipoAviso = keyof Preferencias;

const COLUMNAS: Record<TipoAviso, string> = {
  productosNuevos: 'productos_nuevos',
  categoriasNuevas: 'categorias_nuevas',
  entraEnLista: 'entra_en_lista',
  saleDeLista: 'sale_de_lista',
  personasNuevas: 'personas_nuevas',
};
export const TIPOS = Object.keys(COLUMNAS) as TipoAviso[];

/** Las de una persona en uno de sus hogares. */
export function preferencias(usuarioId: number, hogarId: string): Preferencias {
  const fila = obtenerBd()
    .prepare('SELECT * FROM avisos WHERE usuario_id = ? AND hogar_id = ?')
    .get(usuarioId, hogarId) as
    | Record<string, number>
    | undefined;
  return Object.fromEntries(TIPOS.map((tipo) => [tipo, fila?.[COLUMNAS[tipo]] === 1])) as unknown as Preferencias;
}

export function cambiarPreferencias(usuarioId: number, hogarId: string, cambios: Partial<Preferencias>): Preferencias {
  const nuevas = { ...preferencias(usuarioId, hogarId), ...cambios };
  const valores = TIPOS.map((tipo) => (nuevas[tipo] ? 1 : 0));
  obtenerBd()
    .prepare(
      `INSERT INTO avisos (usuario_id, hogar_id, ${TIPOS.map((t) => COLUMNAS[t]).join(', ')})
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(usuario_id, hogar_id) DO UPDATE SET ${TIPOS.map((t) => `${COLUMNAS[t]} = excluded.${COLUMNAS[t]}`).join(', ')}`,
    )
    .run(usuarioId, hogarId, ...valores);
  return nuevas;
}

export type Entorno = 'produccion' | 'desarrollo';

export interface Dispositivo {
  token: string;
  plataforma: string;
  entorno: Entorno;
}

export function registrarDispositivo(usuarioId: number, d: Dispositivo, ahora = Date.now()): void {
  obtenerBd()
    .prepare(
      `INSERT INTO dispositivos (token, usuario_id, plataforma, entorno, actualizado_en) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET usuario_id = excluded.usuario_id, plataforma = excluded.plataforma,
         entorno = excluded.entorno, actualizado_en = excluded.actualizado_en`,
    )
    .run(d.token, usuarioId, d.plataforma, d.entorno, ahora);
}

/** Solo si es de esa cuenta: nadie puede quitar el dispositivo de otra. */
export function quitarDispositivo(usuarioId: number, token: string): void {
  obtenerBd().prepare('DELETE FROM dispositivos WHERE token = ? AND usuario_id = ?').run(token, usuarioId);
}

/** Cuando Apple dice que un token ya no vale. */
export function olvidarToken(token: string): void {
  obtenerBd().prepare('DELETE FROM dispositivos WHERE token = ?').run(token);
}

/** Los dispositivos de las demás personas del hogar que quieren este aviso de este hogar. */
export function destinatarios(hogarId: string, quienHizo: number, tipo: TipoAviso): Dispositivo[] {
  return obtenerBd()
    .prepare(
      `SELECT d.token, d.plataforma, d.entorno FROM dispositivos d
       JOIN miembros m ON m.usuario_id = d.usuario_id
       JOIN avisos a ON a.usuario_id = d.usuario_id AND a.hogar_id = m.hogar_id
       WHERE m.hogar_id = ? AND d.usuario_id != ? AND a.${COLUMNAS[tipo]} = 1`,
    )
    .all(hogarId, quienHizo) as Dispositivo[];
}
