// Exporta cada hogar de Firestore a un JSON que la app nativa importa desde
// Ajustes → Importar datos. Solo lee: no cambia nada en Firestore.
//
// Uso:
//   cd scripts/exportar-firestore && npm install
//   node exportar.js --clave=/ruta/a/clave-cuenta-servicio.json
//
// La clave se descarga en la consola de Firebase: Configuración del proyecto →
// Cuentas de servicio → Generar nueva clave privada. No la guardes dentro del
// repositorio. Los archivos salen en exportacion-firestore/, en la raíz del
// repositorio, que está en .gitignore.

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const { convertirHogar, nombreDeArchivo } = require('./convertir');

function leerArgumentos(argv) {
  const argumentos = { clave: process.env.GOOGLE_APPLICATION_CREDENTIALS, salida: path.join(__dirname, '..', '..', 'exportacion-firestore') };
  for (const argumento of argv) {
    const [nombre, valor] = argumento.split('=');
    if (nombre === '--clave') argumentos.clave = valor;
    else if (nombre === '--salida') argumentos.salida = valor;
    else throw new Error(`Opción desconocida: ${argumento}`);
  }
  if (!argumentos.clave) {
    throw new Error('Falta la clave: usa --clave=<ruta> o GOOGLE_APPLICATION_CREDENTIALS.');
  }
  return argumentos;
}

async function leerColeccion(referencia) {
  const instantanea = await referencia.get();
  return instantanea.docs.map((documento) => ({ id: documento.id, datos: documento.data() }));
}

async function main() {
  const { clave, salida } = leerArgumentos(process.argv.slice(2));
  const cuenta = JSON.parse(fs.readFileSync(path.resolve(clave), 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(cuenta) });
  const db = admin.firestore();

  fs.mkdirSync(salida, { recursive: true });
  const hogares = await db.collection('households').get();
  if (hogares.empty) {
    console.log('No hay hogares en Firestore.');
  }

  for (const hogar of hogares.docs) {
    const [categorias, productos] = await Promise.all([
      leerColeccion(hogar.ref.collection('categorias')),
      leerColeccion(hogar.ref.collection('productos')),
    ]);
    const { exportacion, resumen } = convertirHogar({ categorias, productos });
    const archivo = path.join(salida, nombreDeArchivo(hogar.data().name, hogar.id));
    fs.writeFileSync(archivo, JSON.stringify(exportacion, null, 2) + '\n');

    let linea = `${hogar.data().name || 'Hogar sin nombre'}: ${resumen.categorias} categorías y ${resumen.productos} productos`;
    if (resumen.sinCategoria > 0) {
      linea += `; ${resumen.sinCategoria} productos sin categoría no se exportan`;
    }
    console.log(`${linea}.\n  → ${archivo}`);
  }

  // Datos de antes de los hogares: la app de Expo los migraba a mano desde Ajustes.
  const [antiguasCategorias, antiguosProductos] = await Promise.all([
    db.collection('categorias').count().get(),
    db.collection('productos').count().get(),
  ]);
  const c = antiguasCategorias.data().count;
  const p = antiguosProductos.data().count;
  if (c + p > 0) {
    console.log(`\nFuera de los hogares quedan ${c} categorías y ${p} productos antiguos. No se exportan.`);
  }
}

main().catch((error) => {
  console.error(`No se pudo exportar: ${error.message}`);
  process.exit(1);
});
