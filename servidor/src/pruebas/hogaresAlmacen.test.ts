import { beforeEach, describe, expect, it } from 'vitest';
import { inicializarBd } from '../db';
import { obtenerOCrearUsuario } from '../auth/usuarios';
import {
  ALFABETO_CODIGO,
  DURACION_INVITACION_MS,
  crearHogar,
  crearInvitacion,
  generarCodigo,
  hogarDeUsuario,
  limpiarNombre,
  purgarHogaresVacios,
  salir,
  unirse,
} from '../hogares/almacen';

const HORA = 60 * 60 * 1000;
const DIA = 24 * HORA;
const T0 = 1_750_000_000_000;

function usuario(nombre: string): number {
  return obtenerOCrearUsuario({
    proveedor: 'google',
    idProveedor: `sub-${nombre}`,
    email: `${nombre.toLowerCase()}@ejemplo.com`,
    nombre,
    emailVerificado: true,
  })!.id;
}

let codigos: string[];
const siguienteCodigo = () => codigos.shift()!;

beforeEach(() => {
  inicializarBd(':memory:');
  codigos = ['AAAA2222', 'BBBB3333', 'CCCC4444'];
});

describe('nombres', () => {
  it('limpia espacios y rechaza vacío o de más de 100 letras', () => {
    expect(limpiarNombre('  Casa   de  campo ')).toBe('Casa de campo');
    expect(limpiarNombre('   ')).toBeUndefined();
    expect(limpiarNombre(42)).toBeUndefined();
    expect(limpiarNombre('ñ'.repeat(100))).toBe('ñ'.repeat(100));
    expect(limpiarNombre('a'.repeat(101))).toBeUndefined();
  });
});

describe('crear hogar', () => {
  it('quien lo crea es miembro y la revisión empieza en 0', () => {
    const ana = usuario('Ana');
    const resultado = crearHogar(ana, 'Casa', () => T0);
    expect('hogar' in resultado && resultado.hogar).toMatchObject({
      nombre: 'Casa',
      revision: 0,
      miembros: [{ id: ana, nombre: 'Ana', email: 'ana@ejemplo.com' }],
    });
  });

  it('no deja crear un segundo hogar', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa');
    expect(crearHogar(ana, 'Otra')).toEqual({ error: 'ya_en_un_hogar' });
  });
});

describe('invitaciones', () => {
  it('los códigos solo usan letras y números que no se confunden', () => {
    const codigo = generarCodigo();
    expect(codigo).toHaveLength(8);
    for (const letra of codigo) expect(ALFABETO_CODIGO).toContain(letra);
    for (const confusa of '0O1IL') expect(ALFABETO_CODIGO).not.toContain(confusa);
  });

  it('sin hogar no se puede invitar', () => {
    expect(crearInvitacion(usuario('Ana'))).toEqual({ error: 'sin_hogar' });
  });

  it('caduca a los 7 días', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa');
    expect(crearInvitacion(ana, () => T0, siguienteCodigo)).toEqual({
      codigo: 'AAAA2222',
      caducaEn: T0 + DURACION_INVITACION_MS,
    });
  });

  it('si el código ya existe prueba otro', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa');
    codigos = ['AAAA2222', 'AAAA2222', 'BBBB3333'];
    crearInvitacion(ana, () => T0, siguienteCodigo);
    expect(crearInvitacion(ana, () => T0, siguienteCodigo)).toMatchObject({ codigo: 'BBBB3333' });
  });
});

describe('unirse', () => {
  function hogarConInvitacion() {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa', () => T0);
    const invitacion = crearInvitacion(ana, () => T0, siguienteCodigo);
    return { ana, codigo: 'codigo' in invitacion ? invitacion.codigo : '' };
  }

  it('entra en el hogar y la invitación queda usada', () => {
    const { ana, codigo } = hogarConInvitacion();
    const luis = usuario('Luis');
    const resultado = unirse(luis, codigo, () => T0 + HORA);
    expect('hogar' in resultado && resultado.hogar.miembros.map((m) => m.id)).toEqual([ana, luis]);

    const eva = usuario('Eva');
    expect(unirse(eva, codigo, () => T0 + HORA)).toEqual({ error: 'codigo_no_valido' });
  });

  it('acepta el código en minúsculas y con espacios', () => {
    hogarConInvitacion();
    expect('hogar' in unirse(usuario('Luis'), ' aaaa 2222 ', () => T0)).toBe(true);
  });

  it('caducado, inexistente o usado dan el mismo error', () => {
    const { codigo } = hogarConInvitacion();
    expect(unirse(usuario('Luis'), codigo, () => T0 + DURACION_INVITACION_MS)).toEqual({
      error: 'codigo_no_valido',
    });
    expect(unirse(usuario('Eva'), 'ZZZZ9999', () => T0)).toEqual({ error: 'codigo_no_valido' });
  });

  it('quien ya está en un hogar no puede unirse a otro', () => {
    const { codigo } = hogarConInvitacion();
    const luis = usuario('Luis');
    crearHogar(luis, 'Piso');
    expect(unirse(luis, codigo, () => T0)).toEqual({ error: 'ya_en_un_hogar' });
    expect(hogarDeUsuario(luis)?.nombre).toBe('Piso');
  });

  it('tras 10 intentos fallidos en una hora bloquea, aunque el código sea bueno', () => {
    const { codigo } = hogarConInvitacion();
    const luis = usuario('Luis');
    for (let i = 0; i < 10; i++) unirse(luis, `MALO${i}`, () => T0 + i);
    expect(unirse(luis, codigo, () => T0 + 20)).toEqual({ error: 'demasiados_intentos' });
    // Pasada la hora vuelve a poder.
    expect('hogar' in unirse(luis, codigo, () => T0 + HORA + 20)).toBe(true);
  });
});

describe('salir y borrar hogares vacíos', () => {
  it('el hogar sigue para los demás', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa', () => T0);
    const invitacion = crearInvitacion(ana, () => T0, siguienteCodigo);
    const luis = usuario('Luis');
    unirse(luis, 'codigo' in invitacion ? invitacion.codigo : '', () => T0);

    expect(salir(ana, () => T0 + DIA)).toEqual({ ok: true });
    expect(hogarDeUsuario(ana)).toBeUndefined();
    expect(hogarDeUsuario(luis)?.miembros.map((m) => m.id)).toEqual([luis]);
    expect(purgarHogaresVacios(() => T0 + 60 * DIA)).toBe(0);
  });

  it('sin nadie, se borra pasados 30 días y no antes', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa', () => T0);
    salir(ana, () => T0);
    expect(purgarHogaresVacios(() => T0 + 29 * DIA)).toBe(0);
    expect(purgarHogaresVacios(() => T0 + 31 * DIA)).toBe(1);
  });

  it('a un hogar vacío no se entra con una invitación antigua', () => {
    const ana = usuario('Ana');
    crearHogar(ana, 'Casa', () => T0);
    const invitacion = crearInvitacion(ana, () => T0, siguienteCodigo);
    salir(ana, () => T0);
    expect(unirse(usuario('Luis'), 'codigo' in invitacion ? invitacion.codigo : '', () => T0)).toEqual({
      error: 'codigo_no_valido',
    });
  });

  it('sin hogar no se puede salir', () => {
    expect(salir(usuario('Ana'))).toEqual({ error: 'sin_hogar' });
  });
});
