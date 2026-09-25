import { beforeEach, describe, expect, it } from 'vitest';
import { inicializarBd, obtenerBd } from '../db';
import { iniciarSesion } from '../auth/sesiones';
import { existeUsuario, obtenerOCrearUsuario } from '../auth/usuarios';
import { borrarCuenta } from '../cuenta/almacen';
import { crearHogar, crearInvitacion, hogarDeUsuario, unirse } from '../hogares/almacen';
import { aplicarLote } from '../sincronizacion/almacen';

function usuario(nombre: string): number {
  return obtenerOCrearUsuario({
    proveedor: 'google',
    idProveedor: `sub-${nombre}`,
    email: `${nombre.toLowerCase()}@ejemplo.com`,
    nombre,
    emailVerificado: true,
  })!.id;
}

function cuenta(tabla: string, where = '1 = 1', ...parametros: unknown[]): number {
  return (obtenerBd().prepare(`SELECT COUNT(*) AS n FROM ${tabla} WHERE ${where}`).get(...parametros) as { n: number }).n;
}

function hogarConInventario(usuarioId: number): string {
  const hogar = crearHogar(usuarioId, 'Casa');
  if (!('hogar' in hogar)) throw new Error('no se creó el hogar');
  aplicarLote(hogar.hogar.id, {
    categorias: [{ id: 'cat-1', nombre: 'Despensa', creado: 1, modificado: 1, borrado: false }],
    productos: [
      {
        id: 'prod-1', categoriaId: 'cat-1', nombre: 'Arroz', umbralCompra: 1, autoListaCompra: true,
        enListaCompraManual: false, creado: 1, modificado: 1, borrado: false,
      },
    ],
    movimientos: [{ id: 'mov-1', productoId: 'prod-1', cambio: 2, momento: 2 }],
  });
  return hogar.hogar.id;
}

beforeEach(() => {
  inicializarBd(':memory:');
});

describe('borrarCuenta', () => {
  it('borra la cuenta y sus sesiones', () => {
    const ana = usuario('Ana');
    iniciarSesion(ana, null);
    iniciarSesion(ana, null);

    expect(borrarCuenta(ana)).toBe(true);

    expect(existeUsuario(ana)).toBe(false);
    expect(cuenta('sesiones', 'usuario_id = ?', ana)).toBe(0);
  });

  it('si no existía, devuelve false', () => {
    expect(borrarCuenta(999)).toBe(false);
  });

  it('si era la única del hogar, borra el hogar y su inventario en el acto', () => {
    const ana = usuario('Ana');
    const hogarId = hogarConInventario(ana);
    crearInvitacion(ana);

    borrarCuenta(ana);

    expect(cuenta('hogares', 'id = ?', hogarId)).toBe(0);
    expect(cuenta('miembros')).toBe(0);
    expect(cuenta('categorias')).toBe(0);
    expect(cuenta('productos')).toBe(0);
    expect(cuenta('movimientos')).toBe(0);
    expect(cuenta('invitaciones')).toBe(0);
  });

  it('si quedan otros miembros, el hogar y el inventario siguen con ellos', () => {
    const ana = usuario('Ana');
    const luis = usuario('Luis');
    const hogarId = hogarConInventario(ana);
    const invitacion = crearInvitacion(ana);
    if (!('codigo' in invitacion)) throw new Error('sin invitación');
    unirse(luis, invitacion.codigo);

    borrarCuenta(ana);

    const hogar = hogarDeUsuario(luis)!;
    expect(hogar.id).toBe(hogarId);
    expect(hogar.miembros.map((m) => m.nombre)).toEqual(['Luis']);
    expect(cuenta('productos', 'hogar_id = ?', hogarId)).toBe(1);
    expect(cuenta('movimientos')).toBe(1);
    // Sigue con gente: no se marca como vacío para purgarlo.
    expect(obtenerBd().prepare('SELECT vacio_desde FROM hogares WHERE id = ?').get(hogarId)).toEqual({
      vacio_desde: null,
    });
  });

  it('borra las invitaciones que creó y quita su rastro de las que usó', () => {
    const ana = usuario('Ana');
    const luis = usuario('Luis');
    hogarConInventario(ana);
    const usada = crearInvitacion(ana);
    if (!('codigo' in usada)) throw new Error('sin invitación');
    unirse(luis, usada.codigo);
    const deLuis = crearInvitacion(luis);
    if (!('codigo' in deLuis)) throw new Error('sin invitación');

    borrarCuenta(luis);

    expect(cuenta('invitaciones', 'creada_por = ?', luis)).toBe(0);
    expect(cuenta('invitaciones', 'usada_por = ?', luis)).toBe(0);
    // La que creó Ana sigue, sin decir quién la usó.
    expect(cuenta('invitaciones', 'codigo = ?', usada.codigo)).toBe(1);
  });

  it('borra sus intentos de unirse y sus inicios de sesión a medias', () => {
    const ana = usuario('Ana');
    unirse(ana, 'MALO2222');
    obtenerBd()
      .prepare(
        `INSERT INTO login_pendientes (estado, modo, creado_en, expira_en, usuario_id)
         VALUES ('e1', 'deeplink', 1, 2, ?)`,
      )
      .run(ana);

    borrarCuenta(ana);

    expect(cuenta('intentos_unirse')).toBe(0);
    expect(cuenta('login_pendientes')).toBe(0);
  });

  it('no toca a los demás', () => {
    const ana = usuario('Ana');
    const eva = usuario('Eva');
    hogarConInventario(eva);
    iniciarSesion(eva, null);

    borrarCuenta(ana);

    expect(existeUsuario(eva)).toBe(true);
    expect(hogarDeUsuario(eva)).toBeDefined();
    expect(cuenta('sesiones', 'usuario_id = ?', eva)).toBe(1);
  });
});
