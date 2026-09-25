const test = require('node:test');
const assert = require('node:assert/strict');
const { convertirHogar, fechaISO, nombreDeArchivo } = require('../convertir');

// Imita un Timestamp de Firestore.
const marca = (iso) => ({ toDate: () => new Date(iso) });

function idsEnOrden() {
  let n = 0;
  return () => `00000000-0000-0000-0000-${String(++n).padStart(12, '0')}`;
}

const ahora = new Date('2026-09-25T12:00:00.000Z');

test('fechas sin milisegundos y con valor por defecto', () => {
  assert.equal(fechaISO(marca('2025-03-01T10:00:00.123Z'), ahora), '2025-03-01T10:00:00Z');
  assert.equal(fechaISO(null, ahora), '2026-09-25T12:00:00Z');
  assert.equal(fechaISO('no es fecha', ahora), '2026-09-25T12:00:00Z');
});

test('convierte categorías y productos con ids nuevos', () => {
  const { exportacion, resumen } = convertirHogar(
    {
      categorias: [{ id: 'catFirestore', datos: { nombre: 'Despensa', createdAt: marca('2025-03-01T10:00:00Z'), ownerUid: 'uid-secreto' } }],
      productos: [
        {
          id: 'prodFirestore',
          datos: {
            nombre: 'Arroz', cantidad: '3', umbralCompra: 1, autoListaCompra: false,
            enListaCompraManual: true, categoriaId: 'catFirestore', ownerUid: 'uid-secreto',
            createdAt: marca('2025-03-01T10:00:00Z'), updatedAt: marca('2025-03-05T18:30:00.500Z'),
          },
        },
      ],
    },
    { ahora, nuevoId: idsEnOrden() },
  );

  assert.deepEqual(resumen, { categorias: 1, productos: 1, sinCategoria: 0 });
  assert.equal(exportacion.formato, 'inventario-casa');
  assert.equal(exportacion.version, 1);
  assert.deepEqual(exportacion.categorias[0], {
    id: '00000000-0000-0000-0000-000000000001',
    nombre: 'Despensa',
    creado: '2025-03-01T10:00:00Z',
    modificado: '2025-03-01T10:00:00Z',
  });
  assert.deepEqual(exportacion.productos[0], {
    id: '00000000-0000-0000-0000-000000000002',
    categoriaId: '00000000-0000-0000-0000-000000000001',
    nombre: 'Arroz',
    cantidad: 3,
    umbralCompra: 1,
    autoListaCompra: false,
    enListaCompraManual: true,
    creado: '2025-03-01T10:00:00Z',
    modificado: '2025-03-05T18:30:00Z',
  });
  assert.ok(!JSON.stringify(exportacion).includes('uid-secreto'));
  assert.ok(!JSON.stringify(exportacion).includes('Firestore'));
});

test('valores por defecto como en la app de Expo', () => {
  const { exportacion } = convertirHogar(
    {
      categorias: [{ id: 'c', datos: { nombre: 'Nevera' } }],
      productos: [{ id: 'p', datos: { nombre: 'Leche', categoriaId: 'c' } }],
    },
    { ahora, nuevoId: idsEnOrden() },
  );
  const leche = exportacion.productos[0];
  assert.equal(leche.cantidad, 0);
  assert.equal(leche.umbralCompra, 2);
  assert.equal(leche.autoListaCompra, true);
  assert.equal(leche.enListaCompraManual, false);
  assert.equal(leche.creado, '2026-09-25T12:00:00Z');
});

test('umbral 0 se conserva y no pasa a 2', () => {
  const { exportacion } = convertirHogar(
    {
      categorias: [{ id: 'c', datos: { nombre: 'Nevera' } }],
      productos: [{ id: 'p', datos: { nombre: 'Leche', categoriaId: 'c', umbralCompra: 0 } }],
    },
    { ahora, nuevoId: idsEnOrden() },
  );
  assert.equal(exportacion.productos[0].umbralCompra, 0);
});

test('productos sin categoría se cuentan y no se exportan', () => {
  const { exportacion, resumen } = convertirHogar(
    { categorias: [], productos: [{ id: 'p', datos: { nombre: 'Huérfano', categoriaId: 'no-existe' } }] },
    { ahora, nuevoId: idsEnOrden() },
  );
  assert.equal(exportacion.productos.length, 0);
  assert.equal(resumen.sinCategoria, 1);
});

test('nombre de archivo', () => {
  assert.equal(nombreDeArchivo('Hogar de José Ñúñez', 'AbCdEfGh1234'), 'hogar-de-jose-nunez-AbCdEfGh.json');
  assert.equal(nombreDeArchivo('', 'xyz'), 'hogar-xyz.json');
});
