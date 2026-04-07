#!/usr/bin/env node

/*
  Safe Firestore cleanup utility for Inventario Casa.
  Default behavior is audit-only (dry run).

  Requirements:
  - Service account JSON file with Firestore admin permissions.
  - Set GOOGLE_APPLICATION_CREDENTIALS or pass --service-account=path.
*/

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COLLECTIONS = {
  HOUSEHOLDS: 'households',
  CATEGORIES: 'categorias',
  PRODUCTS: 'productos',
  LEGACY_CATEGORIES: 'categorias',
  LEGACY_PRODUCTS: 'productos',
  BACKUP: '_cleanupBackups',
};

function parseArgs(argv) {
  const args = {
    help: false,
    mode: 'audit',
    dryRun: true,
    doBackup: true,
    includeLegacy: false,
    cleanupLegacy: false,
    fixDuplicates: false,
    householdIds: [],
    userId: null,
    serviceAccount: null,
  };

  for (const raw of argv.slice(2)) {
    if (raw === '--help' || raw === '-h') {
      args.help = true;
      continue;
    }
    if (raw === '--apply') {
      args.mode = 'apply';
      args.dryRun = false;
      continue;
    }
    if (raw === '--audit' || raw === '--dry-run') {
      args.mode = 'audit';
      args.dryRun = true;
      continue;
    }
    if (raw === '--no-backup') {
      args.doBackup = false;
      continue;
    }
    if (raw === '--include-legacy') {
      args.includeLegacy = true;
      continue;
    }
    if (raw === '--cleanup-legacy') {
      args.includeLegacy = true;
      args.cleanupLegacy = true;
      continue;
    }
    if (raw === '--fix-duplicates') {
      args.fixDuplicates = true;
      continue;
    }

    const [key, value] = raw.split('=');
    if (!value) continue;

    if (key === '--household-id') {
      args.householdIds = value.split(',').map((v) => v.trim()).filter(Boolean);
      continue;
    }
    if (key === '--user-id') {
      args.userId = value.trim();
      continue;
    }
    if (key === '--service-account') {
      args.serviceAccount = value.trim();
      continue;
    }
  }

  if (args.cleanupLegacy && !args.userId) {
    throw new Error('Para --cleanup-legacy debes indicar --user-id=<uid>.');
  }

  return args;
}

function printHelp() {
  console.log(`
Uso:
  node scripts/firestore-safe-cleanup.js --audit [opciones]
  node scripts/firestore-safe-cleanup.js --apply [opciones]

Opciones principales:
  --service-account=<ruta-json>   Ruta al Service Account de Firebase
  --household-id=<id1,id2>        Limitar limpieza/auditoria a hogares concretos
  --user-id=<uid>                 UID objetivo para operaciones de legacy
  --include-legacy                Incluir analisis de colecciones legacy top-level
  --cleanup-legacy                En modo --apply, borra legacy no perteneciente a --user-id
  --fix-duplicates                En modo --apply, fusiona duplicados de categorias/productos
  --no-backup                     No guardar copia en _cleanupBackups antes de borrar
  --help                          Mostrar esta ayuda

Seguridad por defecto:
  - Sin --apply, solo auditoria (no modifica datos).
  - Aunque uses --apply, no fusiona duplicados sin --fix-duplicates.
  - Backup activado por defecto antes de borrados.
`);
}

function normalizeName(value) {
  return String(value || '').trim().toLowerCase();
}

function toNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function initAdmin(serviceAccountPath) {
  if (admin.apps.length > 0) return;

  const resolvedPath = serviceAccountPath || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!resolvedPath) {
    throw new Error(
      'Falta credencial. Usa GOOGLE_APPLICATION_CREDENTIALS o --service-account=<ruta-json>.',
    );
  }

  const absolute = path.resolve(resolvedPath);
  if (!fs.existsSync(absolute)) {
    throw new Error(`No existe el archivo de credenciales: ${absolute}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(absolute, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

async function getHouseholdRefs(db, householdIds) {
  if (householdIds.length > 0) {
    return householdIds.map((id) => db.collection(COLLECTIONS.HOUSEHOLDS).doc(id));
  }

  const snap = await db.collection(COLLECTIONS.HOUSEHOLDS).get();
  return snap.docs.map((d) => d.ref);
}

function groupBy(items, keyFn) {
  const map = new Map();
  for (const item of items) {
    const key = keyFn(item);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }
  return map;
}

function pickCanonical(docs) {
  return [...docs].sort((a, b) => {
    const aTs = a.data().createdAt?.toMillis?.() || Number.MAX_SAFE_INTEGER;
    const bTs = b.data().createdAt?.toMillis?.() || Number.MAX_SAFE_INTEGER;
    if (aTs !== bTs) return aTs - bTs;
    return a.id.localeCompare(b.id);
  })[0];
}

async function backupDoc(db, targetRef, payload) {
  const backupRef = db.collection(COLLECTIONS.BACKUP).doc();
  await backupRef.set({
    ...payload,
    backupCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
    backupPath: targetRef.path,
  });
}

async function analyzeHousehold(db, householdRef) {
  const categoriesSnap = await householdRef.collection(COLLECTIONS.CATEGORIES).get();
  const productsSnap = await householdRef.collection(COLLECTIONS.PRODUCTS).get();

  const categories = categoriesSnap.docs;
  const products = productsSnap.docs;

  const categoryIds = new Set(categories.map((c) => c.id));

  const duplicateCategoryGroups = [...groupBy(categories, (doc) => normalizeName(doc.data().nombre)).entries()]
    .filter(([key, docs]) => key && docs.length > 1)
    .map(([key, docs]) => ({ key, docs }));

  const duplicateProductGroups = [...groupBy(products, (doc) => {
    const d = doc.data();
    return `${d.categoriaId || 'NO_CAT'}::${normalizeName(d.nombre)}`;
  }).entries()]
    .filter(([key, docs]) => !key.endsWith('::') && docs.length > 1)
    .map(([key, docs]) => ({ key, docs }));

  const orphanProducts = products.filter((p) => {
    const categoriaId = p.data().categoriaId;
    return !categoriaId || !categoryIds.has(categoriaId);
  });

  const invalidQuantityProducts = products.filter((p) => {
    const q = p.data().cantidad;
    return !Number.isFinite(Number(q)) || Number(q) < 0;
  });

  return {
    householdId: householdRef.id,
    counts: {
      categories: categories.length,
      products: products.length,
    },
    duplicateCategoryGroups,
    duplicateProductGroups,
    orphanProducts,
    invalidQuantityProducts,
  };
}

async function applyHouseholdFixes(db, report, options) {
  const changes = {
    categoryDuplicatesMerged: 0,
    productDuplicatesMerged: 0,
    orphanProductsRemoved: 0,
    invalidQuantitiesNormalized: 0,
  };

  const householdRef = db.collection(COLLECTIONS.HOUSEHOLDS).doc(report.householdId);

  for (const group of report.duplicateCategoryGroups) {
    if (!options.fixDuplicates) continue;

    const canonical = pickCanonical(group.docs);
    const toDelete = group.docs.filter((d) => d.id !== canonical.id);

    for (const dup of toDelete) {
      const productsSnap = await householdRef
        .collection(COLLECTIONS.PRODUCTS)
        .where('categoriaId', '==', dup.id)
        .get();

      const batch = db.batch();

      for (const prod of productsSnap.docs) {
        batch.update(prod.ref, {
          categoriaId: canonical.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (options.doBackup) {
        await backupDoc(db, dup.ref, {
          reason: 'duplicate-category',
          householdId: report.householdId,
          canonicalId: canonical.id,
          original: dup.data(),
        });
      }

      batch.delete(dup.ref);
      await batch.commit();
      changes.categoryDuplicatesMerged += 1;
    }
  }

  for (const group of report.duplicateProductGroups) {
    if (!options.fixDuplicates) continue;

    const canonical = pickCanonical(group.docs);
    const toDelete = group.docs.filter((d) => d.id !== canonical.id);

    let mergedQty = toNumber(canonical.data().cantidad, 0);
    for (const dup of toDelete) {
      mergedQty += toNumber(dup.data().cantidad, 0);
    }

    const batch = db.batch();
    batch.update(canonical.ref, {
      cantidad: mergedQty,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (const dup of toDelete) {
      if (options.doBackup) {
        await backupDoc(db, dup.ref, {
          reason: 'duplicate-product',
          householdId: report.householdId,
          canonicalId: canonical.id,
          original: dup.data(),
        });
      }
      batch.delete(dup.ref);
      changes.productDuplicatesMerged += 1;
    }

    await batch.commit();
  }

  for (const orphan of report.orphanProducts) {
    if (options.doBackup) {
      await backupDoc(db, orphan.ref, {
        reason: 'orphan-product',
        householdId: report.householdId,
        original: orphan.data(),
      });
    }
    await orphan.ref.delete();
    changes.orphanProductsRemoved += 1;
  }

  for (const product of report.invalidQuantityProducts) {
    await product.ref.update({
      cantidad: Math.max(0, toNumber(product.data().cantidad, 0)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    changes.invalidQuantitiesNormalized += 1;
  }

  return changes;
}

async function analyzeLegacy(db, userId) {
  const [legacyCategoriesSnap, legacyProductsSnap] = await Promise.all([
    db.collection(COLLECTIONS.LEGACY_CATEGORIES).get(),
    db.collection(COLLECTIONS.LEGACY_PRODUCTS).get(),
  ]);

  const legacyCategories = legacyCategoriesSnap.docs;
  const legacyProducts = legacyProductsSnap.docs;

  const suspiciousCategories = legacyCategories.filter((d) => d.data().ownerUid !== userId);
  const suspiciousProducts = legacyProducts.filter((d) => d.data().ownerUid !== userId);

  return {
    total: {
      categories: legacyCategories.length,
      products: legacyProducts.length,
    },
    suspicious: {
      categories: suspiciousCategories,
      products: suspiciousProducts,
    },
  };
}

async function applyLegacyCleanup(db, legacyReport, options) {
  const changes = {
    legacyCategoriesRemoved: 0,
    legacyProductsRemoved: 0,
  };

  for (const category of legacyReport.suspicious.categories) {
    if (options.doBackup) {
      await backupDoc(db, category.ref, {
        reason: 'legacy-category-not-owned',
        userId: options.userId,
        original: category.data(),
      });
    }
    await category.ref.delete();
    changes.legacyCategoriesRemoved += 1;
  }

  for (const product of legacyReport.suspicious.products) {
    if (options.doBackup) {
      await backupDoc(db, product.ref, {
        reason: 'legacy-product-not-owned',
        userId: options.userId,
        original: product.data(),
      });
    }
    await product.ref.delete();
    changes.legacyProductsRemoved += 1;
  }

  return changes;
}

async function run() {
  const options = parseArgs(process.argv);

  if (options.help) {
    printHelp();
    return;
  }

  initAdmin(options.serviceAccount);
  const db = admin.firestore();

  const report = {
    mode: options.mode,
    dryRun: options.dryRun,
    doBackup: options.doBackup,
    includeLegacy: options.includeLegacy,
    cleanupLegacy: options.cleanupLegacy,
    fixDuplicates: options.fixDuplicates,
    householdIds: options.householdIds,
    userId: options.userId,
    households: [],
    legacy: null,
    applied: {
      households: {},
      legacy: null,
    },
  };

  const householdRefs = await getHouseholdRefs(db, options.householdIds);

  for (const householdRef of householdRefs) {
    const householdReport = await analyzeHousehold(db, householdRef);
    report.households.push({
      householdId: householdReport.householdId,
      counts: householdReport.counts,
      anomalies: {
        duplicateCategoryGroups: householdReport.duplicateCategoryGroups.map((g) => ({
          key: g.key,
          ids: g.docs.map((d) => d.id),
        })),
        duplicateProductGroups: householdReport.duplicateProductGroups.map((g) => ({
          key: g.key,
          ids: g.docs.map((d) => d.id),
        })),
        orphanProductIds: householdReport.orphanProducts.map((d) => d.id),
        invalidQuantityProductIds: householdReport.invalidQuantityProducts.map((d) => d.id),
      },
    });

    if (!options.dryRun) {
      const applied = await applyHouseholdFixes(db, householdReport, options);
      report.applied.households[householdReport.householdId] = applied;
    }
  }

  if (options.includeLegacy) {
    if (!options.userId) {
      throw new Error('Para incluir legado debes indicar --user-id=<uid>.');
    }

    const legacyReport = await analyzeLegacy(db, options.userId);
    report.legacy = {
      total: legacyReport.total,
      suspicious: {
        categoryIds: legacyReport.suspicious.categories.map((d) => d.id),
        productIds: legacyReport.suspicious.products.map((d) => d.id),
      },
    };

    if (!options.dryRun && options.cleanupLegacy) {
      report.applied.legacy = await applyLegacyCleanup(db, legacyReport, options);
    }
  }

  console.log(JSON.stringify(report, null, 2));
}

run().catch((error) => {
  console.error('Cleanup script failed:', error.message || error);
  process.exit(1);
});
