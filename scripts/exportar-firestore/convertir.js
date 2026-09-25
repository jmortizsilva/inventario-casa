// Conversión de los datos de Firestore al formato de importación de la app
// nativa (`Exportacion` en el núcleo). Sin conexión: se prueba sola.

const { randomUUID } = require('node:crypto');

const FORMATO = 'inventario-casa';
const VERSION = 1;

// ISO 8601 sin milisegundos: es lo que lee `.iso8601` de Foundation.
function fechaISO(valor, porDefecto) {
  let fecha = null;
  if (valor && typeof valor.toDate === 'function') {
    fecha = valor.toDate();
  } else if (valor instanceof Date) {
    fecha = valor;
  } else if (typeof valor === 'string' || typeof valor === 'number') {
    fecha = new Date(valor);
  }
  if (!fecha || Number.isNaN(fecha.getTime())) {
    fecha = porDefecto;
  }
  return fecha.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function entero(valor, porDefecto) {
  const numero = Number.parseInt(valor, 10);
  return Number.isFinite(numero) ? numero : porDefecto;
}

/**
 * @param {{categorias: {id: string, datos: object}[], productos: {id: string, datos: object}[]}} hogar
 * @returns {{exportacion: object, resumen: {categorias: number, productos: number, sinCategoria: number}}}
 *
 * Los identificadores de Firestore se sustituyen por UUID nuevos y no se
 * copian ownerUid ni ningún dato del hogar o de las personas.
 */
function convertirHogar(hogar, { ahora = new Date(), nuevoId = randomUUID } = {}) {
  const idNuevoDeCategoria = new Map();
  const categorias = hogar.categorias.map(({ id, datos }) => {
    const nuevo = nuevoId();
    idNuevoDeCategoria.set(id, nuevo);
    const creado = fechaISO(datos.createdAt, ahora);
    return {
      id: nuevo,
      nombre: String(datos.nombre ?? ''),
      creado,
      modificado: fechaISO(datos.updatedAt, new Date(creado)),
    };
  });

  let sinCategoria = 0;
  const productos = [];
  for (const { datos } of hogar.productos) {
    const categoriaId = idNuevoDeCategoria.get(datos.categoriaId);
    if (!categoriaId) {
      sinCategoria += 1;
      continue;
    }
    const creado = fechaISO(datos.createdAt, ahora);
    productos.push({
      id: nuevoId(),
      categoriaId,
      nombre: String(datos.nombre ?? ''),
      cantidad: entero(datos.cantidad, 0),
      umbralCompra: entero(datos.umbralCompra, 2),
      autoListaCompra: datos.autoListaCompra !== false,
      enListaCompraManual: datos.enListaCompraManual === true,
      creado,
      modificado: fechaISO(datos.updatedAt, new Date(creado)),
    });
  }

  return {
    exportacion: { formato: FORMATO, version: VERSION, categorias, productos },
    resumen: { categorias: categorias.length, productos: productos.length, sinCategoria },
  };
}

// Para el nombre del archivo: sin tildes, espacios ni símbolos.
function nombreDeArchivo(nombreHogar, idHogar) {
  const limpio = String(nombreHogar ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return `${limpio || 'hogar'}-${String(idHogar).slice(0, 8)}.json`;
}

module.exports = { convertirHogar, fechaISO, nombreDeArchivo };
