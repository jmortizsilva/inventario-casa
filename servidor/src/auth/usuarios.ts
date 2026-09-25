import { obtenerBd } from '../db';
import { PerfilOAuth } from './oauth';

export interface Usuario {
  id: number;
  email: string;
  nombre: string | null;
  proveedor: string;
}

interface FilaUsuario {
  id: number;
  email: string;
  nombre: string | null;
  proveedor: string;
}

// Busca el usuario por (proveedor, idProveedor); si no existe, lo crea. El registro es abierto:
// entrar con Google o Apple la primera vez ES darse de alta, no hace falta que nadie invite.
//
// La identidad es el par (proveedor, idProveedor), nunca el correo: el "sub" del proveedor es
// estable y el correo no (se puede cambiar en Google, y Apple da un alias de reenvio distinto por
// aplicacion). Por eso el mismo correo en Google y en Apple son dos cuentas distintas.
//
// Solo devuelve undefined si el proveedor no da correo: la columna email es NOT NULL.
export function obtenerOCrearUsuario(
  perfil: PerfilOAuth,
  ahora: () => number = () => Date.now(),
): Usuario | undefined {
  const bd = obtenerBd();
  const existente = bd
    .prepare('SELECT id, email, nombre, proveedor FROM usuarios WHERE proveedor = ? AND id_proveedor = ?')
    .get(perfil.proveedor, perfil.idProveedor) as FilaUsuario | undefined;
  if (existente) {
    // Si antes no se tenía el nombre (por ejemplo, entró antes de pedirse el scope profile), se
    // completa ahora.
    if (!existente.nombre && perfil.nombre) {
      bd.prepare('UPDATE usuarios SET nombre = ? WHERE id = ?').run(perfil.nombre, existente.id);
      return { ...existente, nombre: perfil.nombre };
    }
    return existente;
  }

  if (!perfil.email) {
    return undefined;
  }

  const resultado = bd
    .prepare(
      `INSERT INTO usuarios (proveedor, id_proveedor, email, nombre, creado_en) VALUES (?, ?, ?, ?, ?)`,
    )
    .run(perfil.proveedor, perfil.idProveedor, perfil.email, perfil.nombre, ahora());
  return {
    id: Number(resultado.lastInsertRowid),
    email: perfil.email,
    nombre: perfil.nombre,
    proveedor: perfil.proveedor,
  };
}

export function obtenerUsuarioPorId(id: number): Usuario | undefined {
  return obtenerBd().prepare('SELECT id, email, nombre, proveedor FROM usuarios WHERE id = ?').get(id) as
    | Usuario
    | undefined;
}

export function existeUsuario(id: number): boolean {
  return obtenerBd().prepare('SELECT 1 FROM usuarios WHERE id = ?').get(id) !== undefined;
}

export function buscarUsuarioPorProveedor(proveedor: string, idProveedor: string): number | undefined {
  const fila = obtenerBd()
    .prepare('SELECT id FROM usuarios WHERE proveedor = ? AND id_proveedor = ?')
    .get(proveedor, idProveedor) as { id: number } | undefined;
  return fila?.id;
}
