import { obtenerBd } from '../db';
import {
  CategoriaEntrante,
  MAXIMO_POR_LOTE,
  MovimientoEntrante,
  ProductoEntrante,
  calcularCantidad,
  ganaLaNueva,
  validarCategoria,
  validarMovimiento,
  validarProducto,
} from './reglas';

// Aplica en SQLite lo que deciden las reglas. Todo lo de un lote va en una transacción.

export interface Categoria {
  id: string;
  nombre: string;
  creado: number;
  modificado: number;
  borrado: boolean;
}

export interface Producto {
  id: string;
  categoriaId: string;
  nombre: string;
  cantidad: number;
  umbralCompra: number;
  autoListaCompra: boolean;
  enListaCompraManual: boolean;
  creado: number;
  modificado: number;
  borrado: boolean;
}

export type Motivo = 'no_valido' | 'sin_categoria' | 'no_aplicable';
export interface Rechazado {
  tipo: 'categoria' | 'producto' | 'movimiento';
  id: string;
  motivo: Motivo;
}

interface FilaCategoria {
  id: string;
  hogar_id: string;
  nombre: string;
  creado: number;
  modificado: number;
  borrado: number;
  revision: number;
}

interface FilaProducto {
  id: string;
  hogar_id: string;
  categoria_id: string;
  nombre: string;
  umbral_compra: number;
  auto_lista_compra: number;
  en_lista_compra_manual: number;
  creado: number;
  modificado: number;
  borrado: number;
  cantidad_fijada: number;
  cantidad_fijada_en: number;
  cantidad: number;
  revision: number;
}

const aCategoria = (f: FilaCategoria): Categoria => ({
  id: f.id,
  nombre: f.nombre,
  creado: f.creado,
  modificado: f.modificado,
  borrado: f.borrado === 1,
});

const aProducto = (f: FilaProducto): Producto => ({
  id: f.id,
  categoriaId: f.categoria_id,
  nombre: f.nombre,
  cantidad: f.cantidad,
  umbralCompra: f.umbral_compra,
  autoListaCompra: f.auto_lista_compra === 1,
  enListaCompraManual: f.en_lista_compra_manual === 1,
  creado: f.creado,
  modificado: f.modificado,
  borrado: f.borrado === 1,
});

function siguienteRevision(hogarId: string): number {
  const bd = obtenerBd();
  bd.prepare('UPDATE hogares SET revision = revision + 1 WHERE id = ?').run(hogarId);
  return (bd.prepare('SELECT revision FROM hogares WHERE id = ?').get(hogarId) as { revision: number }).revision;
}

const idDe = (dato: unknown): string =>
  typeof dato === 'object' && dato !== null && typeof (dato as { id?: unknown }).id === 'string'
    ? (dato as { id: string }).id
    : '';

const comoObjeto = (dato: unknown): Record<string, unknown> =>
  typeof dato === 'object' && dato !== null ? (dato as Record<string, unknown>) : {};

export interface Lote {
  categorias?: unknown;
  productos?: unknown;
  movimientos?: unknown;
}

export type ResultadoLote =
  | { categorias: Categoria[]; productos: Producto[]; rechazados: Rechazado[]; revision: number }
  | { error: 'demasiados' };

export function aplicarLote(hogarId: string, lote: Lote): ResultadoLote {
  const lista = (valor: unknown): unknown[] => (Array.isArray(valor) ? valor : []);
  const categorias = lista(lote.categorias);
  const productos = lista(lote.productos);
  const movimientos = lista(lote.movimientos);
  if (categorias.length + productos.length + movimientos.length > MAXIMO_POR_LOTE) {
    return { error: 'demasiados' };
  }

  const bd = obtenerBd();
  return bd.transaction(() => {
    const rechazados: Rechazado[] = [];
    const categoriasTocadas = new Set<string>();
    const productosTocados = new Set<string>();

    for (const dato of categorias) {
      const categoria = validarCategoria(comoObjeto(dato));
      if (!categoria) {
        rechazados.push({ tipo: 'categoria', id: idDe(dato), motivo: 'no_valido' });
        continue;
      }
      const motivo = aplicarCategoria(hogarId, categoria, productosTocados);
      if (motivo) rechazados.push({ tipo: 'categoria', id: categoria.id, motivo });
      else categoriasTocadas.add(categoria.id);
    }

    for (const dato of productos) {
      const producto = validarProducto(comoObjeto(dato));
      if (!producto) {
        rechazados.push({ tipo: 'producto', id: idDe(dato), motivo: 'no_valido' });
        continue;
      }
      const motivo = aplicarProducto(hogarId, producto);
      if (motivo) rechazados.push({ tipo: 'producto', id: producto.id, motivo });
      else productosTocados.add(producto.id);
    }

    for (const dato of movimientos) {
      const movimiento = validarMovimiento(comoObjeto(dato));
      if (!movimiento) {
        rechazados.push({ tipo: 'movimiento', id: idDe(dato), motivo: 'no_valido' });
        continue;
      }
      if (!aplicarMovimiento(hogarId, movimiento)) {
        rechazados.push({ tipo: 'movimiento', id: movimiento.id, motivo: 'no_aplicable' });
      } else {
        productosTocados.add(movimiento.productoId);
      }
    }

    // Un solo recálculo por producto, aunque le lleguen muchos movimientos.
    for (const id of productosTocados) recalcularCantidad(id);

    const buscarCategoria = bd.prepare('SELECT * FROM categorias WHERE id = ?');
    const buscarProducto = bd.prepare('SELECT * FROM productos WHERE id = ?');
    return {
      categorias: [...categoriasTocadas].map((id) => aCategoria(buscarCategoria.get(id) as FilaCategoria)),
      productos: [...productosTocados].map((id) => aProducto(buscarProducto.get(id) as FilaProducto)),
      rechazados,
      revision: (bd.prepare('SELECT revision FROM hogares WHERE id = ?').get(hogarId) as { revision: number })
        .revision,
    };
  })();
}

function aplicarCategoria(hogarId: string, nueva: CategoriaEntrante, productosTocados: Set<string>): Motivo | undefined {
  const bd = obtenerBd();
  const existente = bd.prepare('SELECT * FROM categorias WHERE id = ?').get(nueva.id) as FilaCategoria | undefined;
  if (existente && existente.hogar_id !== hogarId) return 'no_aplicable';
  if (!ganaLaNueva(existente?.modificado, nueva.modificado)) return undefined;

  const revision = siguienteRevision(hogarId);
  bd.prepare(
    `INSERT INTO categorias (id, hogar_id, nombre, creado, modificado, borrado, revision)
     VALUES (@id, @hogarId, @nombre, @creado, @modificado, @borrado, @revision)
     ON CONFLICT(id) DO UPDATE SET nombre = @nombre, modificado = @modificado,
       borrado = @borrado, revision = @revision`,
  ).run({ ...nueva, hogarId, borrado: nueva.borrado ? 1 : 0, revision });

  if (nueva.borrado) {
    // Borrar una categoría borra sus productos, para que nadie se quede con productos sueltos.
    const vivos = bd
      .prepare('SELECT id FROM productos WHERE categoria_id = ? AND borrado = 0')
      .all(nueva.id) as { id: string }[];
    for (const { id } of vivos) {
      bd.prepare('UPDATE productos SET borrado = 1, revision = ? WHERE id = ?').run(siguienteRevision(hogarId), id);
      productosTocados.add(id);
    }
  }
  return undefined;
}

function aplicarProducto(hogarId: string, nuevo: ProductoEntrante): Motivo | undefined {
  const bd = obtenerBd();
  const existente = bd.prepare('SELECT * FROM productos WHERE id = ?').get(nuevo.id) as FilaProducto | undefined;
  if (existente && existente.hogar_id !== hogarId) return 'no_aplicable';
  const categoria = bd.prepare('SELECT hogar_id, borrado FROM categorias WHERE id = ?').get(nuevo.categoriaId) as
    | { hogar_id: string; borrado: number }
    | undefined;
  if (!categoria || categoria.hogar_id !== hogarId) return 'sin_categoria';

  // En una categoría borrada solo puede quedar borrado, llegue cuando llegue.
  const borrado = nuevo.borrado || categoria.borrado === 1;
  const gana = ganaLaNueva(existente?.modificado, nuevo.modificado);
  // La cantidad fijada va por su propia hora: puede entrar aunque el resto del registro pierda.
  const fijadaGana = nuevo.fijada !== undefined && nuevo.fijada.en > (existente?.cantidad_fijada_en ?? -1);
  if (!gana && !fijadaGana && !(borrado && existente?.borrado === 0)) return undefined;

  const base = existente ?? {
    categoria_id: nuevo.categoriaId,
    nombre: nuevo.nombre,
    umbral_compra: nuevo.umbralCompra,
    auto_lista_compra: nuevo.autoListaCompra ? 1 : 0,
    en_lista_compra_manual: nuevo.enListaCompraManual ? 1 : 0,
    creado: nuevo.creado,
    modificado: nuevo.modificado,
    borrado: 0,
    cantidad_fijada: 0,
    cantidad_fijada_en: 0,
  };
  const fila = {
    id: nuevo.id,
    hogarId,
    categoriaId: gana ? nuevo.categoriaId : base.categoria_id,
    nombre: gana ? nuevo.nombre : base.nombre,
    umbral: gana ? nuevo.umbralCompra : base.umbral_compra,
    auto: gana ? (nuevo.autoListaCompra ? 1 : 0) : base.auto_lista_compra,
    manual: gana ? (nuevo.enListaCompraManual ? 1 : 0) : base.en_lista_compra_manual,
    creado: base.creado,
    modificado: gana ? nuevo.modificado : base.modificado,
    borrado: borrado || (!gana && base.borrado === 1) ? 1 : 0,
    fijada: fijadaGana ? nuevo.fijada!.cantidad : base.cantidad_fijada,
    fijadaEn: fijadaGana ? nuevo.fijada!.en : base.cantidad_fijada_en,
    revision: siguienteRevision(hogarId),
  };
  bd.prepare(
    `INSERT INTO productos (id, hogar_id, categoria_id, nombre, umbral_compra, auto_lista_compra,
       en_lista_compra_manual, creado, modificado, borrado, cantidad_fijada, cantidad_fijada_en, revision)
     VALUES (@id, @hogarId, @categoriaId, @nombre, @umbral, @auto, @manual, @creado, @modificado,
       @borrado, @fijada, @fijadaEn, @revision)
     ON CONFLICT(id) DO UPDATE SET categoria_id = @categoriaId, nombre = @nombre,
       umbral_compra = @umbral, auto_lista_compra = @auto, en_lista_compra_manual = @manual,
       modificado = @modificado, borrado = @borrado, cantidad_fijada = @fijada,
       cantidad_fijada_en = @fijadaEn, revision = @revision`,
  ).run(fila);
  return undefined;
}

// Devuelve false si el producto no existe en este hogar. Repetir un movimiento ya guardado no
// cuenta doble, pero tampoco es un error: el móvil puede reenviar un lote que no vio confirmado.
function aplicarMovimiento(hogarId: string, movimiento: MovimientoEntrante): boolean {
  const bd = obtenerBd();
  const producto = bd.prepare('SELECT hogar_id FROM productos WHERE id = ?').get(movimiento.productoId) as
    | { hogar_id: string }
    | undefined;
  if (!producto || producto.hogar_id !== hogarId) return false;
  const existente = bd.prepare('SELECT producto_id FROM movimientos WHERE id = ?').get(movimiento.id) as
    | { producto_id: string }
    | undefined;
  if (existente) return existente.producto_id === movimiento.productoId;
  bd.prepare('INSERT INTO movimientos (id, producto_id, cambio, momento) VALUES (?, ?, ?, ?)').run(
    movimiento.id,
    movimiento.productoId,
    movimiento.cambio,
    movimiento.momento,
  );
  return true;
}

function recalcularCantidad(productoId: string): void {
  const bd = obtenerBd();
  const fila = bd.prepare('SELECT * FROM productos WHERE id = ?').get(productoId) as FilaProducto | undefined;
  if (!fila) return;
  const movimientos = bd
    .prepare('SELECT cambio, momento FROM movimientos WHERE producto_id = ?')
    .all(productoId) as { cambio: number; momento: number }[];
  const cantidad = calcularCantidad(fila.cantidad_fijada, fila.cantidad_fijada_en, movimientos);
  if (cantidad !== fila.cantidad) {
    bd.prepare('UPDATE productos SET cantidad = ?, revision = ? WHERE id = ?').run(
      cantidad,
      siguienteRevision(fila.hogar_id),
      productoId,
    );
  }
}

export interface Novedades {
  categorias: Categoria[];
  productos: Producto[];
  revision: number;
  masDisponible: boolean;
}

// Lo cambiado después de `desde`, en orden de revisión, contando categorías y productos juntos.
export function novedadesDesde(hogarId: string, desde: number, limite: number): Novedades {
  const bd = obtenerBd();
  const cats = bd
    .prepare('SELECT * FROM categorias WHERE hogar_id = ? AND revision > ? ORDER BY revision LIMIT ?')
    .all(hogarId, desde, limite + 1) as FilaCategoria[];
  const prods = bd
    .prepare('SELECT * FROM productos WHERE hogar_id = ? AND revision > ? ORDER BY revision LIMIT ?')
    .all(hogarId, desde, limite + 1) as FilaProducto[];
  const todas = [
    ...cats.map((fila) => ({ revision: fila.revision, categoria: fila })),
    ...prods.map((fila) => ({ revision: fila.revision, producto: fila })),
  ].sort((a, b) => a.revision - b.revision);

  const masDisponible = todas.length > limite;
  const incluidas = todas.slice(0, limite);
  const revisionHogar = (bd.prepare('SELECT revision FROM hogares WHERE id = ?').get(hogarId) as { revision: number })
    .revision;
  return {
    categorias: incluidas.flatMap((e) => ('categoria' in e && e.categoria ? [aCategoria(e.categoria)] : [])),
    productos: incluidas.flatMap((e) => ('producto' in e && e.producto ? [aProducto(e.producto)] : [])),
    // Si queda más, la siguiente página empieza tras lo último entregado; si no, tras todo el hogar.
    revision: masDisponible ? incluidas[incluidas.length - 1].revision : revisionHogar,
    masDisponible,
  };
}
