// Esquema de la base de datos. Es la fuente de la verdad: se aplica al arrancar.

export const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proveedor TEXT NOT NULL,
  id_proveedor TEXT NOT NULL,
  email TEXT NOT NULL,
  nombre TEXT,
  creado_en INTEGER NOT NULL,
  activo INTEGER NOT NULL DEFAULT 1,
  UNIQUE (proveedor, id_proveedor)
);

CREATE TABLE IF NOT EXISTS login_pendientes (
  estado TEXT PRIMARY KEY,
  modo TEXT NOT NULL,
  esquema TEXT,
  creado_en INTEGER NOT NULL,
  expira_en INTEGER NOT NULL,
  codigo_canje TEXT,
  usuario_id INTEGER REFERENCES usuarios(id),
  error TEXT
);

CREATE INDEX IF NOT EXISTS idx_login_pendientes_codigo_canje
  ON login_pendientes (codigo_canje);

CREATE TABLE IF NOT EXISTS sesiones (
  id TEXT PRIMARY KEY,
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  hash_token_refresco TEXT NOT NULL,
  dispositivo TEXT,
  creado_en INTEGER NOT NULL,
  ultimo_uso_en INTEGER,
  expira_en INTEGER NOT NULL,
  revocado_en INTEGER
);

CREATE INDEX IF NOT EXISTS idx_sesiones_usuario ON sesiones (usuario_id);

-- revision: último número dado a un cambio de este hogar (ver CONTRATO-API.md).
-- vacio_desde: cuándo salió la última persona; a los 30 días se borra.
CREATE TABLE IF NOT EXISTS hogares (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  creado_en INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0,
  vacio_desde INTEGER
);

-- La clave primaria es usuario_id: así la base de datos misma impide estar en dos hogares.
CREATE TABLE IF NOT EXISTS miembros (
  usuario_id INTEGER PRIMARY KEY REFERENCES usuarios(id),
  hogar_id TEXT NOT NULL REFERENCES hogares(id),
  unido_en INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_miembros_hogar ON miembros (hogar_id);

CREATE TABLE IF NOT EXISTS invitaciones (
  codigo TEXT PRIMARY KEY,
  hogar_id TEXT NOT NULL REFERENCES hogares(id),
  creada_por INTEGER NOT NULL REFERENCES usuarios(id),
  creada_en INTEGER NOT NULL,
  caduca_en INTEGER NOT NULL,
  usada_en INTEGER,
  usada_por INTEGER REFERENCES usuarios(id)
);

-- Intentos fallidos de unirse, para limitar a quien pruebe códigos a ciegas.
CREATE TABLE IF NOT EXISTS intentos_unirse (
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  momento INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_intentos_unirse ON intentos_unirse (usuario_id, momento);

-- Inventario de cada hogar. revision: número del hogar dado al último cambio de la fila.
-- modificado: hora del móvil, solo para decidir qué versión gana.
CREATE TABLE IF NOT EXISTS categorias (
  id TEXT PRIMARY KEY,
  hogar_id TEXT NOT NULL REFERENCES hogares(id),
  nombre TEXT NOT NULL,
  creado INTEGER NOT NULL,
  modificado INTEGER NOT NULL,
  borrado INTEGER NOT NULL DEFAULT 0,
  revision INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_categorias_hogar_revision ON categorias (hogar_id, revision);

-- cantidad es el resultado ya calculado de cantidad_fijada + movimientos posteriores.
CREATE TABLE IF NOT EXISTS productos (
  id TEXT PRIMARY KEY,
  hogar_id TEXT NOT NULL REFERENCES hogares(id),
  categoria_id TEXT NOT NULL,
  nombre TEXT NOT NULL,
  umbral_compra INTEGER NOT NULL,
  auto_lista_compra INTEGER NOT NULL,
  en_lista_compra_manual INTEGER NOT NULL,
  creado INTEGER NOT NULL,
  modificado INTEGER NOT NULL,
  borrado INTEGER NOT NULL DEFAULT 0,
  cantidad_fijada INTEGER NOT NULL DEFAULT 0,
  cantidad_fijada_en INTEGER NOT NULL DEFAULT 0,
  cantidad INTEGER NOT NULL DEFAULT 0,
  revision INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_productos_hogar_revision ON productos (hogar_id, revision);
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos (categoria_id);

CREATE TABLE IF NOT EXISTS movimientos (
  id TEXT PRIMARY KEY,
  producto_id TEXT NOT NULL REFERENCES productos(id),
  cambio INTEGER NOT NULL,
  momento INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_movimientos_producto ON movimientos (producto_id);
`;
