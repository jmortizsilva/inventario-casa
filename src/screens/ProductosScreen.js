import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Alert,
  AccessibilityInfo,
  Platform
} from 'react-native';
import { useBottomTabBarHeight } from '@react-navigation/bottom-tabs';
import { 
  subscribeToProducts, 
  updateProductQuantity, 
  deleteProduct,
  updateProduct
} from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function ProductosScreen({ route, navigation }) {
  const { householdId } = useAuth();
  const { categoriaId, categoriaNombre } = route.params;
  const [productos, setProductos] = useState([]);
  const [screenReaderEnabled, setScreenReaderEnabled] = useState(false);
  const listRef = useRef(null);
  const tabBarHeight = useBottomTabBarHeight();

  useEffect(() => {
    let mounted = true;

    AccessibilityInfo.isScreenReaderEnabled().then((enabled) => {
      if (mounted) {
        setScreenReaderEnabled(Boolean(enabled));
      }
    });

    const subscription = AccessibilityInfo.addEventListener('screenReaderChanged', (enabled) => {
      setScreenReaderEnabled(Boolean(enabled));
    });

    return () => {
      mounted = false;
      subscription?.remove?.();
    };
  }, []);

  const adjustFocusScroll = useCallback((index, total) => {
    if (Platform.OS !== 'ios' || !screenReaderEnabled || !listRef.current) {
      return;
    }

    if (index < Math.max(0, total - 3)) {
      return;
    }

    requestAnimationFrame(() => {
      listRef.current?.scrollToIndex({
        index,
        viewPosition: 0.82,
        animated: true,
      });
    });
  }, [screenReaderEnabled]);

  useEffect(() => {
    navigation.setOptions({ title: categoriaNombre });

    if (!householdId) {
      return () => {};
    }
    
    // Suscripción en tiempo real a los productos
    const unsubscribe = subscribeToProducts(householdId, categoriaId, (data) => {
      setProductos(
        data.map((product) => ({
          ...product,
          autoListaCompra: product.autoListaCompra ?? true,
          enListaCompraManual: product.enListaCompraManual ?? false,
        }))
      );
    });

    return () => unsubscribe();
  }, [categoriaId, householdId]);

  const incrementarCantidad = async (producto) => {
    const nuevaCantidad = producto.cantidad + 1;
    const result = await updateProductQuantity(householdId, producto.id, nuevaCantidad);
    if (result.success && Platform.OS === 'ios') {
      AccessibilityInfo.announceForAccessibility(
        `${producto.nombre}: cantidad actualizada a ${nuevaCantidad}`
      );
    }
  };

  const decrementarCantidad = async (producto) => {
    const nuevaCantidad = Math.max(0, producto.cantidad - 1);
    const result = await updateProductQuantity(householdId, producto.id, nuevaCantidad);
    if (result.success && Platform.OS === 'ios') {
      AccessibilityInfo.announceForAccessibility(
        `${producto.nombre}: cantidad actualizada a ${nuevaCantidad}`
      );
    }
  };

  const handleEliminar = (id, nombre) => {
    Alert.alert(
      'Confirmar eliminación',
      `¿Eliminar "${nombre}"?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Eliminar',
          style: 'destructive',
          onPress: async () => {
            const result = await deleteProduct(householdId, id);
            if (result.success) {
              AccessibilityInfo.announceForAccessibility(`${nombre} eliminado`);
            }
          }
        }
      ]
    );
  };

  const toggleManualLista = async (producto) => {
    const nuevoEstado = !(producto.enListaCompraManual ?? false);
    const result = await updateProduct(householdId, producto.id, {
      enListaCompraManual: nuevoEstado,
    });

    if (result.success && Platform.OS === 'ios') {
      AccessibilityInfo.announceForAccessibility(
        nuevoEstado
          ? `${producto.nombre} añadido manualmente a la lista de compra`
          : `${producto.nombre} quitado de la lista de compra manual`
      );
    }
  };

  const renderProducto = ({ item, index }) => (
    <TouchableOpacity
      style={styles.productoCard}
      activeOpacity={0.9}
      onPress={() => navigation.navigate('EditarProducto', {
        producto: item,
        categoriaId,
        categoriaNombre
      })}
      accessible={true}
      accessibilityRole="button"
      accessibilityLanguage="es-ES"
      accessibilityLabel={`${item.nombre}, ${item.cantidad} unidades`}
      accessibilityHint="Doble toque para editar. Usa las acciones del rotor para otras opciones"
      accessibilityActions={[
        { name: 'editarProducto', label: 'Editar producto' },
        { name: 'aumentarCantidad', label: 'Aumentar cantidad' },
        { name: 'disminuirCantidad', label: 'Disminuir cantidad' },
        {
          name: 'listaCompra',
          label: item.enListaCompraManual
            ? 'Lista de compra: quitar'
            : 'Lista de compra: añadir',
        },
        { name: 'eliminarProducto', label: 'Eliminar producto' }
      ]}
      onAccessibilityAction={(event) => {
        switch (event.nativeEvent.actionName) {
          case 'editarProducto':
            navigation.navigate('EditarProducto', { 
              producto: item,
              categoriaId,
              categoriaNombre 
            });
            break;
          case 'aumentarCantidad':
            incrementarCantidad(item);
            break;
          case 'disminuirCantidad':
            decrementarCantidad(item);
            break;
          case 'listaCompra':
            toggleManualLista(item);
            break;
          case 'eliminarProducto':
            handleEliminar(item.id, item.nombre);
            break;
        }
      }}
      onFocus={() => adjustFocusScroll(index, productos.length)}
    >
      <View style={styles.productoInfo} importantForAccessibility="no-hide-descendants">
        <Text 
          style={styles.productoNombre}
          accessibilityElementsHidden={true}
          importantForAccessibility="no"
        >
          {item.nombre}
        </Text>
        <Text 
          style={styles.productoCantidad}
          accessibilityElementsHidden={true}
          importantForAccessibility="no"
        >
          Cantidad: {item.cantidad}
        </Text>
      </View>

      <View 
        style={styles.botonesContainer}
        importantForAccessibility="no-hide-descendants"
      >
        <TouchableOpacity
          style={styles.botonMenos}
          onPress={() => decrementarCantidad(item)}
          accessible={false}
          importantForAccessibility="no"
        >
          <Text style={styles.botonTexto}>−</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.botonMas}
          onPress={() => incrementarCantidad(item)}
          accessible={false}
          importantForAccessibility="no"
        >
          <Text style={styles.botonTexto}>+</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.botonEditar}
          onPress={() => navigation.navigate('EditarProducto', { 
            producto: item,
            categoriaId,
            categoriaNombre 
          })}
          onLongPress={() => handleEliminar(item.id, item.nombre)}
          accessible={false}
          importantForAccessibility="no"
        >
          <Text style={styles.botonEditarTexto}>✎</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[
            styles.botonLista,
            item.enListaCompraManual && styles.botonListaActivo,
          ]}
          onPress={() => toggleManualLista(item)}
          accessible={false}
          importantForAccessibility="no"
        >
          <Text style={styles.botonEditarTexto}>🛒</Text>
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      {productos.length === 0 ? (
        <View style={[styles.emptyContainer, { paddingBottom: tabBarHeight + 24 }]}>
          <Text 
            style={styles.emptyText}
            accessible={true}
            accessibilityLabel="No hay productos en esta categoría. Añade un producto con el botón más"
          >
            No hay productos en esta categoría.{'\n'}Añade uno con el botón +
          </Text>
        </View>
      ) : (
        <FlatList
          ref={listRef}
          data={productos}
          renderItem={renderProducto}
          keyExtractor={(item) => item.id}
          contentContainerStyle={[styles.lista, { paddingBottom: tabBarHeight + 30 }]}
          keyboardShouldPersistTaps="handled"
          onScrollToIndexFailed={({ averageItemLength = 120, index }) => {
            listRef.current?.scrollToOffset({
              offset: Math.max(0, (averageItemLength * index) - averageItemLength),
              animated: true,
            });
          }}
          accessible={false}
          accessibilityLabel={`Lista de ${productos.length} productos`}
        />
      )}

      <TouchableOpacity
        style={[styles.botonFlotante, { bottom: tabBarHeight + 16 }]}
        onPress={() => navigation.navigate('NuevoProducto', { categoriaId, categoriaNombre })}
        accessible={true}
        accessibilityLabel="Añadir nuevo producto"
        accessibilityRole="button"
        accessibilityHint="Toca para crear un producto nuevo"
      >
        <Text style={styles.botonTexto}>+</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  lista: {
    padding: 15,
  },
  productoCard: {
    backgroundColor: '#fff',
    padding: 15,
    marginBottom: 10,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  productoInfo: {
    marginBottom: 15,
  },
  productoNombre: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginBottom: 5,
  },
  productoCantidad: {
    fontSize: 16,
    color: '#666',
  },
  botonesContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 10,
  },
  botonMenos: {
    flex: 1,
    backgroundColor: '#FF3B30',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    minHeight: 50,
    justifyContent: 'center',
  },
  botonMas: {
    flex: 1,
    backgroundColor: '#34C759',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    minHeight: 50,
    justifyContent: 'center',
  },
  botonEditar: {
    flex: 1,
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    minHeight: 50,
    justifyContent: 'center',
  },
  botonLista: {
    flex: 1,
    backgroundColor: '#8E8E93',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    minHeight: 50,
    justifyContent: 'center',
  },
  botonListaActivo: {
    backgroundColor: '#1F8B4C',
  },
  botonTexto: {
    fontSize: 24,
    color: '#fff',
    fontWeight: 'bold',
  },
  botonEditarTexto: {
    fontSize: 20,
    color: '#fff',
    fontWeight: 'bold',
  },
  botonFlotante: {
    position: 'absolute',
    right: 20,
    bottom: 20,
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 8,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    fontSize: 18,
    color: '#666',
    textAlign: 'center',
    lineHeight: 28,
  },
});
