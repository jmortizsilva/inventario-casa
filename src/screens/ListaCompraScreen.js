import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  AccessibilityInfo,
  Alert,
} from 'react-native';
import { collection, query, where, onSnapshot, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import { db } from '../services/firebase';

export default function ListaCompraScreen() {
  const [productosCompra, setProductosCompra] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Query para obtener todos los productos con cantidad <= 2
    const q = query(
      collection(db, 'productos'),
      where('cantidad', '<=', 2)
    );

    const unsubscribe = onSnapshot(q, (querySnapshot) => {
      const productos = [];
      querySnapshot.forEach((doc) => {
        productos.push({
          id: doc.id,
          ...doc.data()
        });
      });

      // Ordenar por cantidad (menor primero) y luego por nombre
      productos.sort((a, b) => {
        if (a.cantidad !== b.cantidad) {
          return a.cantidad - b.cantidad;
        }
        return a.nombre.localeCompare(b.nombre);
      });

      setProductosCompra(productos);
      setLoading(false);

      // Anunciar actualización para VoiceOver
      if (productos.length > 0) {
        AccessibilityInfo.announceForAccessibility(
          `Lista de compra actualizada. ${productos.length} ${productos.length === 1 ? 'producto' : 'productos'} con pocas unidades.`
        );
      }
    });

    return () => unsubscribe();
  }, []);

  const incrementarCantidad = async (productoId, cantidadActual, nombreProducto) => {
    try {
      const nuevaCantidad = cantidadActual + 1;
      const productoRef = doc(db, 'productos', productoId);
      await updateDoc(productoRef, {
        cantidad: nuevaCantidad
      });

      AccessibilityInfo.announceForAccessibility(
        `${nombreProducto}: ${nuevaCantidad} ${nuevaCantidad === 1 ? 'unidad' : 'unidades'}`
      );

      // Si supera 2 unidades, anunciar que se elimina de la lista
      if (nuevaCantidad > 2) {
        AccessibilityInfo.announceForAccessibility(
          `${nombreProducto} eliminado de la lista de compra`
        );
      }
    } catch (error) {
      console.error('Error al incrementar cantidad:', error);
      Alert.alert('Error', 'No se pudo actualizar la cantidad');
    }
  };

  const decrementarCantidad = async (productoId, cantidadActual, nombreProducto) => {
    if (cantidadActual === 0) return;

    try {
      const nuevaCantidad = cantidadActual - 1;
      const productoRef = doc(db, 'productos', productoId);
      await updateDoc(productoRef, {
        cantidad: nuevaCantidad
      });

      AccessibilityInfo.announceForAccessibility(
        `${nombreProducto}: ${nuevaCantidad} ${nuevaCantidad === 1 ? 'unidad' : 'unidades'}`
      );
    } catch (error) {
      console.error('Error al decrementar cantidad:', error);
      Alert.alert('Error', 'No se pudo actualizar la cantidad');
    }
  };

  const renderProducto = ({ item }) => {
    const urgente = item.cantidad === 0;
    
    return (
      <View 
        style={[
          styles.productoCard,
          urgente && styles.productoUrgente
        ]}
        accessible={true}
        accessibilityLabel={`${item.nombre}, ${item.cantidad} ${item.cantidad === 1 ? 'unidad' : 'unidades'}${urgente ? ', urgente' : ''}`}
        accessibilityHint="Desliza arriba para incrementar, abajo para decrementar"
        accessibilityActions={[
          { name: 'increment', label: 'Incrementar cantidad' },
          { name: 'decrement', label: 'Decrementar cantidad' },
        ]}
        onAccessibilityAction={(event) => {
          switch (event.nativeEvent.actionName) {
            case 'increment':
              incrementarCantidad(item.id, item.cantidad, item.nombre);
              break;
            case 'decrement':
              decrementarCantidad(item.id, item.cantidad, item.nombre);
              break;
          }
        }}
      >
        <View style={styles.infoContainer}>
          <Text style={[styles.nombre, urgente && styles.nombreUrgente]}>
            {item.nombre}
          </Text>
          <Text style={[styles.cantidad, urgente && styles.cantidadUrgente]}>
            {item.cantidad} {item.cantidad === 1 ? 'unidad' : 'unidades'}
          </Text>
          {urgente && (
            <Text style={styles.etiquetaUrgente}>¡URGENTE!</Text>
          )}
        </View>

        <View style={styles.botonesContainer}>
          <TouchableOpacity
            style={styles.botonCantidad}
            onPress={() => decrementarCantidad(item.id, item.cantidad, item.nombre)}
            accessibilityLabel="Decrementar cantidad"
            accessibilityRole="button"
            disabled={item.cantidad === 0}
          >
            <Text style={[styles.botonTexto, item.cantidad === 0 && styles.botonDeshabilitado]}>−</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.botonCantidad}
            onPress={() => incrementarCantidad(item.id, item.cantidad, item.nombre)}
            accessibilityLabel="Incrementar cantidad"
            accessibilityRole="button"
          >
            <Text style={styles.botonTexto}>+</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Cargando lista de compra...</Text>
        </View>
      </View>
    );
  }

  if (productosCompra.length === 0) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyIcon}>✓</Text>
          <Text style={styles.emptyText}>¡Todo bien!</Text>
          <Text style={styles.emptySubtext}>
            No hay productos con pocas unidades
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerInfo}>
        <Text style={styles.headerText}>
          {productosCompra.length} {productosCompra.length === 1 ? 'producto' : 'productos'} para comprar
        </Text>
      </View>
      
      <FlatList
        data={productosCompra}
        renderItem={renderProducto}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.lista}
        accessible={false}
        importantForAccessibility="no"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
  },
  headerInfo: {
    backgroundColor: '#007AFF',
    padding: 15,
    alignItems: 'center',
  },
  headerText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 18,
    color: '#666',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  emptyIcon: {
    fontSize: 80,
    marginBottom: 20,
  },
  emptyText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#007AFF',
    marginBottom: 10,
  },
  emptySubtext: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  lista: {
    padding: 15,
  },
  productoCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderWidth: 2,
    borderColor: '#E5E5EA',
  },
  productoUrgente: {
    borderColor: '#FF3B30',
    backgroundColor: '#FFF5F5',
  },
  infoContainer: {
    flex: 1,
    marginRight: 15,
  },
  nombre: {
    fontSize: 20,
    fontWeight: '600',
    color: '#000',
    marginBottom: 8,
  },
  nombreUrgente: {
    color: '#FF3B30',
  },
  cantidad: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  cantidadUrgente: {
    color: '#FF3B30',
    fontWeight: '600',
  },
  etiquetaUrgente: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#FF3B30',
    marginTop: 4,
  },
  botonesContainer: {
    flexDirection: 'row',
    gap: 10,
  },
  botonCantidad: {
    backgroundColor: '#007AFF',
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 3,
    elevation: 4,
  },
  botonTexto: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: 'bold',
  },
  botonDeshabilitado: {
    opacity: 0.3,
  },
});
