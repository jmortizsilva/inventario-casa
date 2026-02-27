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

// ============ CATEGORÍAS ============

export const subscribeToCategories = (callback) => {
  const q = query(collection(db, 'categorias'), orderBy('nombre'));
  return onSnapshot(q, (snapshot) => {
    const categorias = [];
    snapshot.forEach((doc) => {
      categorias.push({ id: doc.id, ...doc.data() });
    });
    callback(categorias);
  });
};

export const addCategory = async (nombre) => {
  try {
    const docRef = await addDoc(collection(db, 'categorias'), {
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

export const updateCategory = async (id, nombre) => {
  try {
    const docRef = doc(db, 'categorias', id);
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

export const deleteCategory = async (id) => {
  try {
    // Eliminar todos los productos de esta categoría primero
    const productosQuery = query(collection(db, 'productos'), where('categoriaId', '==', id));
    const productosSnapshot = await getDocs(productosQuery);
    const deletePromises = productosSnapshot.docs.map((doc) => deleteDoc(doc.ref));
    await Promise.all(deletePromises);
    
    // Eliminar la categoría
    await deleteDoc(doc(db, 'categorias', id));
    return { success: true };
  } catch (error) {
    console.error('Error al eliminar categoría:', error);
    return { success: false, error: error.message };
  }
};

// ============ PRODUCTOS ============

export const subscribeToProducts = (categoriaId, callback) => {
  const q = query(
    collection(db, 'productos'), 
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

export const addProduct = async (nombre, cantidad, categoriaId, umbralCompra = 2) => {
  try {
    const docRef = await addDoc(collection(db, 'productos'), {
      nombre,
      cantidad: parseInt(cantidad) || 0,
      umbralCompra: parseInt(umbralCompra) || 2,
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

export const updateProduct = async (id, updates) => {
  try {
    const sanitizedUpdates = { ...updates };

    if (sanitizedUpdates.cantidad !== undefined) {
      sanitizedUpdates.cantidad = parseInt(sanitizedUpdates.cantidad) || 0;
    }

    if (sanitizedUpdates.umbralCompra !== undefined) {
      sanitizedUpdates.umbralCompra = parseInt(sanitizedUpdates.umbralCompra) || 2;
    }

    const docRef = doc(db, 'productos', id);
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

export const updateProductQuantity = async (id, cantidad) => {
  return updateProduct(id, { cantidad: parseInt(cantidad) || 0 });
};

export const deleteProduct = async (id) => {
  try {
    await deleteDoc(doc(db, 'productos', id));
    return { success: true };
  } catch (error) {
    console.error('Error al eliminar producto:', error);
    return { success: false, error: error.message };
  }
};
