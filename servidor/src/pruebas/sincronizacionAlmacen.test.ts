import { beforeEach, describe, expect, it } from 'vitest';
import { inicializarBd } from '../db';
import { obtenerOCrearUsuario } from '../auth/usuarios';
import { crearHogar } from '../hogares/almacen';
import { aplicarLote, novedadesDesde, Lote } from '../sincronizacion/almacen';

let hogar: string;
let otroHogar: string;

function nuevoHogar(nombre: string): string {
  const id = obtenerOCrearUsuario({
    proveedor: 'google',
    idProveedor: `sub-${nombre}`,
    email: `${nombre}@ejemplo.com`,
    nombre,
    emailVerificado: true,
  })!.id;
  const resultado = crearHogar(id, nombre);
  if (!('hogar' in resultado)) throw new Error('no se creó el hogar');
  return resultado.hogar.id;
}

const cat = (id: string, modificado: number, extra: object = {}) => ({
  id,
  nombre: 'Despensa',
  creado: 1,
  modificado,
  ...extra,
});
const prod = (id: string, modificado: number, extra: object = {}) => ({
  id,
  categoriaId: 'c1',
  nombre: 'Arroz',
  umbralCompra: 2,
  autoListaCompra: true,
  enListaCompraManual: false,
  creado: 1,
  modificado,
  ...extra,
});
const mov = (id: string, cambio: number, momento: number, productoId = 'p1') => ({ id, productoId, cambio, momento });

function aplicar(lote: Lote, enHogar = hogar) {
  const resultado = aplicarLote(enHogar, lote);
  if ('error' in resultado) throw new Error(resultado.error);
  return resultado;
}

beforeEach(() => {
  inicializarBd(':memory:');
  hogar = nuevoHogar('ana');
  otroHogar = nuevoHogar('luis');
});

describe('altas y revisión', () => {
  it('una categoría y su producto en el mismo lote', () => {
    const r = aplicar({
      categorias: [cat('c1', 10)],
      productos: [prod('p1', 10, { cantidad: 3, cantidadFijadaEn: 10 })],
    });
    expect(r.rechazados).toEqual([]);
    expect(r.categorias.map((c) => c.id)).toEqual(['c1']);
    expect(r.productos[0]).toMatchObject({ id: 'p1', cantidad: 3, borrado: false });
    expect(r.revision).toBeGreaterThan(0);
  });

  it('producto sin categoría en el hogar: sin_categoria', () => {
    const r = aplicar({ productos: [prod('p1', 10)] });
    expect(r.rechazados).toEqual([{ tipo: 'producto', id: 'p1', motivo: 'sin_categoria' }]);
  });

  it('datos no válidos: no_valido, y el resto del lote se aplica', () => {
    const r = aplicar({ categorias: [cat('c1', 10), { id: 'c2', nombre: '', creado: 1, modificado: 1 }] });
    expect(r.categorias.map((c) => c.id)).toEqual(['c1']);
    expect(r.rechazados).toEqual([{ tipo: 'categoria', id: 'c2', motivo: 'no_valido' }]);
  });

  it('más de 1000 entradas: se rechaza el lote entero', () => {
    const categorias = Array.from({ length: 1001 }, (_, i) => cat(`c${i}`, 1));
    expect(aplicarLote(hogar, { categorias })).toEqual({ error: 'demasiados' });
  });
});

describe('conflictos', () => {
  beforeEach(() => {
    aplicar({ categorias: [cat('c1', 10)], productos: [prod('p1', 10)] });
  });

  it('gana la versión más reciente, llegue cuando llegue', () => {
    aplicar({ productos: [prod('p1', 30, { nombre: 'Arroz integral' })] });
    const r = aplicar({ productos: [prod('p1', 20, { nombre: 'Arroz basmati' })] });
    expect(r.productos[0].nombre).toBe('Arroz integral');
  });

  it('con la misma hora se queda la que había', () => {
    aplicar({ productos: [prod('p1', 30, { nombre: 'Uno' })] });
    const r = aplicar({ productos: [prod('p1', 30, { nombre: 'Dos' })] });
    expect(r.productos[0].nombre).toBe('Uno');
  });

  it('un id de otro hogar: no_aplicable, sin tocar nada', () => {
    const r = aplicar({ categorias: [cat('c1', 99, { nombre: 'Robada' })] }, otroHogar);
    expect(r.rechazados).toEqual([{ tipo: 'categoria', id: 'c1', motivo: 'no_aplicable' }]);
    expect(novedadesDesde(hogar, 0, 10).categorias[0].nombre).toBe('Despensa');
  });
});

describe('unidades', () => {
  beforeEach(() => {
    aplicar({ categorias: [cat('c1', 10)], productos: [prod('p1', 10, { cantidad: 2, cantidadFijadaEn: 10 })] });
  });

  it('dos personas restan a la vez: cuentan las dos', () => {
    aplicar({ movimientos: [mov('m-ana', -1, 50)] });
    const r = aplicar({ movimientos: [mov('m-luis', -1, 50)] });
    expect(r.productos[0].cantidad).toBe(0);
  });

  it('reenviar el mismo movimiento no cuenta doble', () => {
    aplicar({ movimientos: [mov('m1', 1, 50)] });
    const r = aplicar({ movimientos: [mov('m1', 1, 50)] });
    expect(r.rechazados).toEqual([]);
    expect(novedadesDesde(hogar, 0, 10).productos[0].cantidad).toBe(3);
  });

  it('fijar desde la ficha anula los movimientos anteriores y no los posteriores', () => {
    aplicar({ movimientos: [mov('m1', 5, 20), mov('m2', 1, 40)] });
    const r = aplicar({ productos: [prod('p1', 30, { cantidad: 10, cantidadFijadaEn: 30 })] });
    expect(r.productos[0].cantidad).toBe(11);
  });

  it('la cantidad fijada entra aunque el resto del registro pierda', () => {
    aplicar({ productos: [prod('p1', 100, { nombre: 'Arroz integral' })] });
    const r = aplicar({ productos: [prod('p1', 50, { nombre: 'Viejo', cantidad: 7, cantidadFijadaEn: 50 })] });
    expect(r.productos[0]).toMatchObject({ nombre: 'Arroz integral', cantidad: 7 });
  });

  it('movimiento sobre un producto de otro hogar o inexistente: no_aplicable', () => {
    const r = aplicar({ movimientos: [mov('m1', 1, 50), mov('m2', 1, 50, 'no-existe')] }, otroHogar);
    expect(r.rechazados.map((x) => x.motivo)).toEqual(['no_aplicable', 'no_aplicable']);
    expect(novedadesDesde(hogar, 0, 10).productos[0].cantidad).toBe(2);
  });
});

describe('borrar una categoría', () => {
  it('borra sus productos, también los que lleguen después', () => {
    aplicar({ categorias: [cat('c1', 10)], productos: [prod('p1', 10)] });
    const r = aplicar({ categorias: [cat('c1', 20, { borrado: true })] });
    expect(r.productos).toEqual([expect.objectContaining({ id: 'p1', borrado: true })]);

    // Alguien sin conexión añadió otro producto a esa categoría, con hora posterior.
    const tarde = aplicar({ productos: [prod('p2', 99)] });
    expect(tarde.productos[0]).toMatchObject({ id: 'p2', borrado: true });
  });
});

describe('novedades por revisión', () => {
  it('solo lo cambiado después, con páginas', () => {
    const primera = aplicar({ categorias: [cat('c1', 10)], productos: [prod('p1', 10)] });
    aplicar({ productos: [prod('p2', 10, { nombre: 'Pasta' }), prod('p3', 10, { nombre: 'Sal' })] });

    const pagina1 = novedadesDesde(hogar, primera.revision, 1);
    expect(pagina1.productos.map((p) => p.id)).toEqual(['p2']);
    expect(pagina1.masDisponible).toBe(true);
    const pagina2 = novedadesDesde(hogar, pagina1.revision, 1);
    expect(pagina2.productos.map((p) => p.id)).toEqual(['p3']);
    expect(pagina2.masDisponible).toBe(false);
    expect(novedadesDesde(hogar, pagina2.revision, 10).productos).toEqual([]);
  });

  it('un cambio con hora del móvil atrasada no se pierde', () => {
    const r = aplicar({ categorias: [cat('c1', 1_000_000)] });
    // El móvil de Luis va muy atrasado: su producto nuevo lleva una hora muy antigua.
    aplicar({ productos: [prod('p1', 5)] });
    expect(novedadesDesde(hogar, r.revision, 10).productos.map((p) => p.id)).toEqual(['p1']);
  });

  it('cada hogar solo ve lo suyo', () => {
    aplicar({ categorias: [cat('c1', 10)] });
    expect(novedadesDesde(otroHogar, 0, 10).categorias).toEqual([]);
  });
});
