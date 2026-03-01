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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useBottomTabBarHeight } from '@react-navigation/bottom-tabs';
import { subscribeToCategories, deleteCategory } from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function CategoriasScreen({ navigation }) {
  const { householdId, householdName } = useAuth();
  const [categorias, setCategorias] = useState([]);
  const [screenReaderEnabled, setScreenReaderEnabled] = useState(false);
  const listRef = useRef(null);
  const insets = useSafeAreaInsets();
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
    if (!householdId) {
      return () => {};
    }

    // Suscripción en tiempo real a las categorías
    const unsubscribe = subscribeToCategories(householdId, (data) => {
      setCategorias(data);
      // Anunciar cambios para VoiceOver
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(
          `Categorías actualizadas. ${data.length} categorías disponibles.`
        );
      }
    });

    return () => unsubscribe();
  }, [householdId]);

  const handleEliminarCategoria = (id, nombre) => {
    Alert.alert(
      'Confirmar eliminación',
      `¿Eliminar la categoría "${nombre}" y todos sus productos?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Eliminar',
          style: 'destructive',
          onPress: async () => {
            const result = await deleteCategory(householdId, id);
            if (result.success) {
              AccessibilityInfo.announceForAccessibility(`Categoría ${nombre} eliminada`);
            } else {
              Alert.alert('Error', 'No se pudo eliminar la categoría');
            }
          }
        }
      ]
    );
  };

  const renderCategoria = ({ item, index }) => (
    <TouchableOpacity
      style={styles.categoriaCard}
      onPress={() => navigation.navigate('Productos', { 
        categoriaId: item.id, 
        categoriaNombre: item.nombre 
      })}
      accessible={true}
      accessibilityLanguage="es-ES"
      accessibilityLabel={item.nombre}
      accessibilityHint="Toca para ver los productos"
      accessibilityActions={[
        { name: 'agregarProducto', label: `Añadir producto a ${item.nombre}` },
        { name: 'editarCategoria', label: 'Editar categoría' },
        { name: 'eliminarCategoria', label: 'Eliminar categoría' }
      ]}
      onAccessibilityAction={(event) => {
        switch (event.nativeEvent.actionName) {
          case 'agregarProducto':
            navigation.navigate('NuevoProducto', {
              categoriaId: item.id,
              categoriaNombre: item.nombre,
            });
            break;
          case 'editarCategoria':
            navigation.navigate('EditarCategoria', { 
              categoriaId: item.id, 
              categoriaNombre: item.nombre 
            });
            break;
          case 'eliminarCategoria':
            handleEliminarCategoria(item.id, item.nombre);
            break;
        }
      }}
      onLongPress={() => navigation.navigate('EditarCategoria', { 
        categoriaId: item.id, 
        categoriaNombre: item.nombre 
      })}
      onFocus={() => adjustFocusScroll(index, categorias.length)}
    >
      <Text style={styles.categoriaNombre}>{item.nombre}</Text>
      <Text 
        style={styles.categoriaFlecha}
        accessibilityElementsHidden={true}
      >
        →
      </Text>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <View 
        style={[styles.header, { paddingTop: insets.top + 16 }]}
        accessible={true}
        accessibilityRole="header"
      >
        <Text style={styles.titulo}>
          {householdName ? `Inventario Casa, ${householdName}` : 'Inventario Casa'}
        </Text>
      </View>

      {categorias.length === 0 ? (
        <View style={[styles.emptyContainer, { paddingBottom: tabBarHeight + 24, paddingTop: insets.top + 16 }]}>
          <Text 
            style={styles.emptyText}
            accessible={true}
            accessibilityLabel="No hay categorías. Añade una categoría nueva con el botón más"
          >
            No hay categorías.{'\n'}Añade una nueva con el botón +
          </Text>
        </View>
      ) : (
        <FlatList
          ref={listRef}
          data={categorias}
          renderItem={renderCategoria}
          keyExtractor={(item) => item.id}
          contentContainerStyle={[
            styles.lista,
            {
              paddingTop: Math.max(10, insets.top * 0.2),
              paddingBottom: tabBarHeight + 30,
            },
          ]}
          keyboardShouldPersistTaps="handled"
          onScrollToIndexFailed={({ averageItemLength = 80, index }) => {
            listRef.current?.scrollToOffset({
              offset: Math.max(0, (averageItemLength * index) - averageItemLength),
              animated: true,
            });
          }}
          accessible={false}
          accessibilityLabel={`Lista de ${categorias.length} categorías`}
        />
      )}

      <TouchableOpacity
        style={[styles.botonFlotante, { bottom: tabBarHeight + 16 }]}
        onPress={() => navigation.navigate('NuevaCategoria')}
        accessible={true}
        accessibilityLabel="Añadir nueva categoría"
        accessibilityRole="button"
        accessibilityHint="Toca para crear una categoría nueva"
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
  header: {
    backgroundColor: '#007AFF',
    padding: 20,
  },
  titulo: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
  },
  lista: {
    padding: 15,
  },
  categoriaCard: {
    backgroundColor: '#fff',
    padding: 20,
    marginBottom: 10,
    borderRadius: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    minHeight: 60,
  },
  categoriaNombre: {
    fontSize: 20,
    color: '#333',
    flex: 1,
  },
  categoriaFlecha: {
    fontSize: 24,
    color: '#007AFF',
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
  botonTexto: {
    fontSize: 32,
    color: '#fff',
    fontWeight: 'bold',
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
