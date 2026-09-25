import { obtenerBd } from '../db';
import { borrarHogar, hogarDeUsuario } from '../hogares/almacen';

// Borrado de la cuenta (ver CONTRATO-API.md, DELETE /cuenta, y docs/SERVIDOR.md, decisión 7).
// Lo personal se borra de verdad; el inventario es del hogar y solo se va si no queda nadie.

// Devuelve false si la cuenta no existía.
export function borrarCuenta(usuarioId: number): boolean {
  const bd = obtenerBd();
  return bd.transaction((): boolean => {
    const existe = bd.prepare('SELECT 1 FROM usuarios WHERE id = ?').get(usuarioId);
    if (!existe) return false;

    const hogar = hogarDeUsuario(usuarioId);
    bd.prepare('DELETE FROM miembros WHERE usuario_id = ?').run(usuarioId);
    // Sin los 30 días de «salir»: ya no queda nadie que pueda volver a entrar en ese hogar.
    if (hogar && hogar.miembros.length === 1) borrarHogar(hogar.id);

    // Las que creó se van todas: las usadas solo eran historia. En las que usó para entrar se
    // quita quién fue, para no dejar su id colgando.
    bd.prepare('DELETE FROM invitaciones WHERE creada_por = ?').run(usuarioId);
    bd.prepare('UPDATE invitaciones SET usada_por = NULL WHERE usada_por = ?').run(usuarioId);

    bd.prepare('DELETE FROM intentos_unirse WHERE usuario_id = ?').run(usuarioId);
    bd.prepare('DELETE FROM login_pendientes WHERE usuario_id = ?').run(usuarioId);
    bd.prepare('DELETE FROM sesiones WHERE usuario_id = ?').run(usuarioId);
    bd.prepare('DELETE FROM usuarios WHERE id = ?').run(usuarioId);
    return true;
  })();
}
