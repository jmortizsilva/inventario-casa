import React, { useState, useEffect } from 'react';
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
import { 
  subscribeToProducts, 
  updateProductQuantity, 
  deleteProduct 
} from '../services/firestore';

export default function ProductosScreen({ route, navigation }) {
  const { categoriaId, categoriaNombre } = route.params;
  const [productos, setProductos] = useState([]);

  useEffect(() => {
    navigation.setOptions({ title: categoriaNombre });
    
    // Suscripción en tiempo real a los productos
    const unsubscribe = subscribeToProducts(categoriaId, (data) => {
      setProductos(data);
    });

    return () => unsubscribe();
  }, [categoriaId]);

  const incrementarCantidad = async (producto) => {
    const nuevaCantidad = producto.cantidad + 1;
    const result = await updateProductQuantity(producto.id, nuevaCantidad);
    if (result.success && Platform.OS === 'ios') {
      AccessibilityInfo.announceForAccessibility(
        `${producto.nombre}: cantidad actualizada a ${nuevaCantidad}`
      );
    }
  };

  const decrementarCantidad = async (producto) => {
    const nuevaCantidad = Math.max(0, producto.cantidad - 1);
    const result = await updateProductQuantity(producto.id, nuevaCantidad);
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
            const result = await deleteProduct(id);
            if (result.success) {
              AccessibilityInfo.announceForAccessibility(`${nombre} eliminado`);
            }
          }
        }
      ]
    );
  };

  const renderProducto = ({ item }) => (
    <View 
      style={styles.productoCard}
      accessible={true}
      accessibilityLabel={`${item.nombre}, ${item.cantidad} unidades`}
      accessibilityHint="Usa las acciones del rotor para aumentar o disminuir"
      accessibilityActions={[
        { name: 'aumentar', label: 'Aumentar cantidad' },
        { name: 'disminuir', label: 'Disminuir cantidad' },
        { name: 'editar', label: 'Editar producto' },
        { name: 'eliminar', label: 'Eliminar producto' }
      ]}
      onAccessibilityAction={(event) => {
        switch (event.nativeEvent.actionName) {
          case 'aumentar':
            incrementarCantidad(item);
            break;
          case 'disminuir':
            decrementarCantidad(item);
            break;
          case 'editar':
            navigation.navigate('EditarProducto', { 
              producto: item,
              categoriaId,
              categoriaNombre 
            });
            break;
          case 'eliminar':
            handleEliminar(item.id, item.nombre);
            break;
        }
      }}
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
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      {productos.length === 0 ? (
        <View style={styles.emptyContainer}>
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
          data={productos}
          renderItem={renderProducto}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.lista}
          accessible={false}
          accessibilityLabel={`Lista de ${productos.length} productos`}
        />
      )}

      <TouchableOpacity
        style={styles.botonFlotante}
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
