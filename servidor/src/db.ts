import Database from 'better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { config } from './config';
import { SCHEMA_SQL } from './esquema';

let bd: Database.Database | undefined;

// Abre (o crea) la base de datos y aplica el esquema. Con ':memory:' se usa una BD en memoria,
// util para los tests. Se llama una vez al arrancar.
export function inicializarBd(rutaBd: string = config.rutaBd): Database.Database {
  if (rutaBd !== ':memory:') {
    mkdirSync(dirname(rutaBd), { recursive: true });
  }
  const db = new Database(rutaBd);
  db.pragma('journal_mode = WAL');
  db.exec(SCHEMA_SQL);
  migrar(db);
  bd = db;
  return db;
}

/** Si la tabla tiene esa columna. */
function tieneColumna(db: Database.Database, tabla: string, columna: string): boolean {
  return (db.pragma(`table_info(${tabla})`) as { name: string }[]).some((c) => c.name === columna);
}

/** Cuántas columnas forman la clave primaria de la tabla. */
function columnasDeLaClave(db: Database.Database, tabla: string): number {
  return (db.pragma(`table_info(${tabla})`) as { pk: number }[]).filter((c) => c.pk > 0).length;
}

/**
 * Lo que CREATE TABLE IF NOT EXISTS no arregla: una tabla que ya existe con otra forma. SQLite
 * no deja cambiar la clave primaria, así que se crea la tabla nueva, se copia y se sustituye,
 * todo en una transacción. Cada paso mira la forma de la tabla y no un número de versión, así
 * que da igual cuántas veces se ejecute.
 */
function migrar(db: Database.Database): void {
  db.transaction(() => {
    // Varios hogares por persona (28 de septiembre de 2026): la clave de miembros era usuario_id.
    if (columnasDeLaClave(db, 'miembros') === 1) {
      db.exec(`
        CREATE TABLE miembros_nueva (
          usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
          hogar_id TEXT NOT NULL REFERENCES hogares(id),
          unido_en INTEGER NOT NULL,
          PRIMARY KEY (usuario_id, hogar_id)
        );
        INSERT INTO miembros_nueva (usuario_id, hogar_id, unido_en) SELECT usuario_id, hogar_id, unido_en FROM miembros;
        DROP TABLE miembros;
        ALTER TABLE miembros_nueva RENAME TO miembros;
        CREATE INDEX IF NOT EXISTS idx_miembros_hogar ON miembros (hogar_id);
      `);
    }
    // Y las notificaciones pasan a ser por hogar: las que había, al hogar que tenía cada persona.
    if (!tieneColumna(db, 'avisos', 'hogar_id')) {
      db.exec(`
        CREATE TABLE avisos_nueva (
          usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
          hogar_id TEXT NOT NULL REFERENCES hogares(id),
          productos_nuevos INTEGER NOT NULL DEFAULT 0,
          categorias_nuevas INTEGER NOT NULL DEFAULT 0,
          entra_en_lista INTEGER NOT NULL DEFAULT 0,
          sale_de_lista INTEGER NOT NULL DEFAULT 0,
          personas_nuevas INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (usuario_id, hogar_id)
        );
        INSERT INTO avisos_nueva
          SELECT a.usuario_id, m.hogar_id, a.productos_nuevos, a.categorias_nuevas, a.entra_en_lista,
                 a.sale_de_lista, a.personas_nuevas
          FROM avisos a JOIN miembros m ON m.usuario_id = a.usuario_id;
        DROP TABLE avisos;
        ALTER TABLE avisos_nueva RENAME TO avisos;
      `);
    }
    // En qué se cuenta cada producto (2 de octubre de 2026). Lo que había, en unidades.
    if (!tieneColumna(db, 'productos', 'unidad')) {
      db.exec(`ALTER TABLE productos ADD COLUMN unidad TEXT NOT NULL DEFAULT 'unidad'`);
    }
  })();
}

export function obtenerBd(): Database.Database {
  if (!bd) {
    throw new Error('Base de datos no inicializada: llama a inicializarBd() primero');
  }
  return bd;
}
