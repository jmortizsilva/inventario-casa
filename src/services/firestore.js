import { 
  collection, 
  doc, 
  addDoc, 
  updateDoc, 
  deleteDoc, 
  getDocs, 
  onSnapshot,
  query,
  orderBy,
  where,
  serverTimestamp 
} from 'firebase/firestore';
import { db } from './firebase';

const getHouseholdPath = (householdId, section) => {
  if (!householdId) {
    throw new Error('No hay hogar seleccionado');
  }
  return collection(db, 'households', householdId, section);
};

// ============ CATEGORÍAS ============

export const subscribeToCategories = (householdId, callback) => {
  const q = query(getHouseholdPath(householdId, 'categorias'), orderBy('nombre'));
  return onSnapshot(q, (snapshot) => {
    const categorias = [];
    snapshot.forEach((doc) => {
      categorias.push({ id: doc.id, ...doc.data() });
    });
    callback(categorias);
  });
};

export const addCategory = async (householdId, nombre) => {
  try {
    const docRef = await addDoc(getHouseholdPath(householdId, 'categorias'), {
      nombre,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    return { success: true, id: docRef.id };
  } catch (error) {
    console.error('Error al añadir categoría:', error);
    return { success: false, error: error.message };
  }
};

export const updateCategory = async (householdId, id, nombre) => {
  try {
    const docRef = doc(db, 'households', householdId, 'categorias', id);
    await updateDoc(docRef, {
      nombre,
      updatedAt: serverTimestamp()
    });
    return { success: true };
  } catch (error) {
    console.error('Error al actualizar categoría:', error);
    return { success: false, error: error.message };
  }
};

export const deleteCategory = async (householdId, id) => {
  try {
    // Eliminar todos los productos de esta categoría primero
    const productosQuery = query(
      getHouseholdPath(householdId, 'productos'),
      where('categoriaId', '==', id)
    );
    const productosSnapshot = await getDocs(productosQuery);
    const deletePromises = productosSnapshot.docs.map((doc) => deleteDoc(doc.ref));
    await Promise.all(deletePromises);
    
    // Eliminar la categoría
    await deleteDoc(doc(db, 'households', householdId, 'categorias', id));
    return { success: true };
  } catch (error) {
    console.error('Error al eliminar categoría:', error);
    return { success: false, error: error.message };
  }
};

// ============ PRODUCTOS ============

export const subscribeToProducts = (householdId, categoriaId, callback) => {
  const q = query(
    getHouseholdPath(householdId, 'productos'), 
    where('categoriaId', '==', categoriaId),
    orderBy('nombre')
  );
  return onSnapshot(q, (snapshot) => {
    const productos = [];
    snapshot.forEach((doc) => {
      productos.push({ id: doc.id, ...doc.data() });
    });
    callback(productos);
  });
};

export const addProduct = async (
  householdId,
  nombre,
  cantidad,
  categoriaId,
  umbralCompra = 2,
  autoListaCompra = true
) => {
  try {
    const docRef = await addDoc(getHouseholdPath(householdId, 'productos'), {
      nombre,
      cantidad: parseInt(cantidad) || 0,
      umbralCompra: parseInt(umbralCompra) || 2,
      autoListaCompra: autoListaCompra !== false,
      enListaCompraManual: false,
      categoriaId,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    return { success: true, id: docRef.id };
  } catch (error) {
    console.error('Error al añadir producto:', error);
    return { success: false, error: error.message };
  }
};

export const updateProduct = async (householdId, id, updates) => {
  try {
    const sanitizedUpdates = { ...updates };

    if (sanitizedUpdates.cantidad !== undefined) {
      sanitizedUpdates.cantidad = parseInt(sanitizedUpdates.cantidad) || 0;
    }

    if (sanitizedUpdates.umbralCompra !== undefined) {
      sanitizedUpdates.umbralCompra = parseInt(sanitizedUpdates.umbralCompra) || 2;
    }

    if (sanitizedUpdates.autoListaCompra !== undefined) {
      sanitizedUpdates.autoListaCompra = Boolean(sanitizedUpdates.autoListaCompra);
    }

    if (sanitizedUpdates.enListaCompraManual !== undefined) {
      sanitizedUpdates.enListaCompraManual = Boolean(sanitizedUpdates.enListaCompraManual);
    }

    const docRef = doc(db, 'households', householdId, 'productos', id);
    await updateDoc(docRef, {
      ...sanitizedUpdates,
      updatedAt: serverTimestamp()
    });
    return { success: true };
  } catch (error) {
    console.error('Error al actualizar producto:', error);
    return { success: false, error: error.message };
  }
};

export const updateProductQuantity = async (householdId, id, cantidad) => {
  return updateProduct(householdId, id, { cantidad: parseInt(cantidad) || 0 });
};

export const deleteProduct = async (householdId, id) => {
  try {
    await deleteDoc(doc(db, 'households', householdId, 'productos', id));
    return { success: true };
  } catch (error) {
    console.error('Error al eliminar producto:', error);
    return { success: false, error: error.message };
  }
};
