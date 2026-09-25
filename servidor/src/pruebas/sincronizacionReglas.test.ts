import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { calcularCantidad, ganaLaNueva, validarCategoria, validarMovimiento, validarProducto } from '../sincronizacion/reglas';

interface Caso {
  caso: string;
  fijada: number;
  fijadaEn: number;
  movimientos: { cambio: number; momento: number }[];
  cantidad: number;
}

// Los mismos casos que usan las apps: están en la raíz del repositorio.
const casos: Caso[] = JSON.parse(
  readFileSync(join(__dirname, '../../../pruebas-compartidas/cantidad.json'), 'utf8'),
).casos;

describe('unidades (casos compartidos)', () => {
  it.each(casos)('$caso', ({ fijada, fijadaEn, movimientos, cantidad }) => {
    expect(calcularCantidad(fijada, fijadaEn, movimientos)).toBe(cantidad);
  });

  it('el resultado no depende del orden de los movimientos', () => {
    const movimientos = [
      { cambio: -1, momento: 110 },
      { cambio: -1, momento: 120 },
      { cambio: 3, momento: 130 },
      { cambio: -2, momento: 90 },
    ];
    const esperado = calcularCantidad(1, 100, movimientos);
    expect(calcularCantidad(1, 100, [...movimientos].reverse())).toBe(esperado);
  });
});

describe('qué versión gana', () => {
  it('la más reciente; si empatan, la que había', () => {
    expect(ganaLaNueva(undefined, 1)).toBe(true);
    expect(ganaLaNueva(100, 101)).toBe(true);
    expect(ganaLaNueva(100, 100)).toBe(false);
    expect(ganaLaNueva(100, 99)).toBe(false);
  });
});

const productoValido = {
  id: 'p1',
  categoriaId: 'c1',
  nombre: 'Arroz',
  umbralCompra: 2,
  autoListaCompra: true,
  enListaCompraManual: false,
  creado: 1,
  modificado: 2,
};

describe('validación', () => {
  it('categoría: limpia el nombre y exige fechas enteras', () => {
    expect(validarCategoria({ id: 'c1', nombre: '  Despensa ', creado: 1, modificado: 2 })).toEqual({
      id: 'c1',
      nombre: 'Despensa',
      creado: 1,
      modificado: 2,
      borrado: false,
    });
    expect(validarCategoria({ id: 'c1', nombre: '', creado: 1, modificado: 2 })).toBeUndefined();
    expect(validarCategoria({ id: 'c1', nombre: 'X', creado: 1.5, modificado: 2 })).toBeUndefined();
  });

  it('producto: umbral entre 0 y 20 y banderas booleanas', () => {
    expect(validarProducto(productoValido)?.fijada).toBeUndefined();
    expect(validarProducto({ ...productoValido, umbralCompra: 21 })).toBeUndefined();
    expect(validarProducto({ ...productoValido, umbralCompra: -1 })).toBeUndefined();
    expect(validarProducto({ ...productoValido, autoListaCompra: 'sí' })).toBeUndefined();
  });

  it('producto: la cantidad fijada va con su hora y se acota', () => {
    expect(validarProducto({ ...productoValido, cantidad: 1500, cantidadFijadaEn: 9 })?.fijada).toEqual({
      cantidad: 999,
      en: 9,
    });
    expect(validarProducto({ ...productoValido, cantidad: 3 })).toBeUndefined();
  });

  it('movimiento: cambio distinto de 0 y como mucho 999', () => {
    const base = { id: 'm1', productoId: 'p1', momento: 5 };
    expect(validarMovimiento({ ...base, cambio: -1 })).toEqual({ ...base, cambio: -1 });
    expect(validarMovimiento({ ...base, cambio: 0 })).toBeUndefined();
    expect(validarMovimiento({ ...base, cambio: 1000 })).toBeUndefined();
    expect(validarMovimiento({ ...base, cambio: 0.5 })).toBeUndefined();
  });
});
