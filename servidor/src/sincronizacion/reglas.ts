// Decisiones de la sincronización, sin base de datos: validar lo que llega, calcular las
// unidades y decidir qué versión gana. Ver CONTRATO-API.md.

import { limpiarNombre } from '../hogares/almacen';

export const CANTIDAD_MINIMA = 0;
export const CANTIDAD_MAXIMA = 999;
export const UMBRAL_MAXIMO = 20;
export const CAMBIO_MAXIMO = 999;
export const MAXIMO_POR_LOTE = 1000;

export interface Movimiento {
  cambio: number;
  momento: number;
}

/**
 * Última cantidad fijada más los movimientos posteriores a esa fijación, acotada al final.
 * Acotar al final, y no paso a paso, es lo que hace que el orden de llegada no importe.
 */
export function calcularCantidad(fijada: number, fijadaEn: number, movimientos: Movimiento[]): number {
  const suma = movimientos
    .filter((movimiento) => movimiento.momento > fijadaEn)
    .reduce((total, movimiento) => total + movimiento.cambio, fijada);
  return Math.min(Math.max(suma, CANTIDAD_MINIMA), CANTIDAD_MAXIMA);
}

/** Gana la versión modificada más tarde; si empatan, se queda la que ya había. */
export function ganaLaNueva(modificadoExistente: number | undefined, modificadoNuevo: number): boolean {
  return modificadoExistente === undefined || modificadoNuevo > modificadoExistente;
}

const esEntero = (valor: unknown): valor is number => Number.isSafeInteger(valor);
const esId = (valor: unknown): valor is string =>
  typeof valor === 'string' && valor.length > 0 && valor.length <= 64;

export interface CategoriaEntrante {
  id: string;
  nombre: string;
  creado: number;
  modificado: number;
  borrado: boolean;
}

export interface ProductoEntrante {
  id: string;
  categoriaId: string;
  nombre: string;
  umbralCompra: number;
  autoListaCompra: boolean;
  enListaCompraManual: boolean;
  creado: number;
  modificado: number;
  borrado: boolean;
  // Solo si se fijó desde la ficha (o al crear): valor final y cuándo.
  fijada?: { cantidad: number; en: number };
}

export interface MovimientoEntrante extends Movimiento {
  id: string;
  productoId: string;
}

// Cada validador devuelve la entrada normalizada, o undefined si no es válida. Del id se ocupa
// quien llama: sin id no hay a quién rechazar.

export function validarCategoria(dato: Record<string, unknown>): CategoriaEntrante | undefined {
  const nombre = limpiarNombre(dato.nombre);
  if (!esId(dato.id) || !nombre || !esEntero(dato.creado) || !esEntero(dato.modificado)) return undefined;
  return { id: dato.id, nombre, creado: dato.creado, modificado: dato.modificado, borrado: dato.borrado === true };
}

export function validarProducto(dato: Record<string, unknown>): ProductoEntrante | undefined {
  const nombre = limpiarNombre(dato.nombre);
  const umbral = dato.umbralCompra;
  if (
    !esId(dato.id) ||
    !esId(dato.categoriaId) ||
    !nombre ||
    !esEntero(umbral) ||
    umbral < 0 ||
    umbral > UMBRAL_MAXIMO ||
    typeof dato.autoListaCompra !== 'boolean' ||
    typeof dato.enListaCompraManual !== 'boolean' ||
    !esEntero(dato.creado) ||
    !esEntero(dato.modificado)
  ) {
    return undefined;
  }
  let fijada: ProductoEntrante['fijada'];
  if (dato.cantidad !== undefined || dato.cantidadFijadaEn !== undefined) {
    if (!esEntero(dato.cantidad) || !esEntero(dato.cantidadFijadaEn)) return undefined;
    // Se guarda acotada: un valor fuera de rango en la ficha no puede llegar a 1500 unidades.
    fijada = {
      cantidad: Math.min(Math.max(dato.cantidad, CANTIDAD_MINIMA), CANTIDAD_MAXIMA),
      en: dato.cantidadFijadaEn,
    };
  }
  return {
    id: dato.id,
    categoriaId: dato.categoriaId,
    nombre,
    umbralCompra: umbral,
    autoListaCompra: dato.autoListaCompra,
    enListaCompraManual: dato.enListaCompraManual,
    creado: dato.creado,
    modificado: dato.modificado,
    borrado: dato.borrado === true,
    fijada,
  };
}

export function validarMovimiento(dato: Record<string, unknown>): MovimientoEntrante | undefined {
  const cambio = dato.cambio;
  if (
    !esId(dato.id) ||
    !esId(dato.productoId) ||
    !esEntero(cambio) ||
    cambio === 0 ||
    Math.abs(cambio) > CAMBIO_MAXIMO ||
    !esEntero(dato.momento)
  ) {
    return undefined;
  }
  return { id: dato.id, productoId: dato.productoId, cambio, momento: dato.momento };
}
