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
import { subscribeToCategories, deleteCategory } from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function CategoriasScreen({ navigation }) {
  const { householdId, householdCode, householdName } = useAuth();
  const [categorias, setCategorias] = useState([]);

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

  const renderCategoria = ({ item }) => (
    <TouchableOpacity
      style={styles.categoriaCard}
      onPress={() => navigation.navigate('Productos', { 
        categoriaId: item.id, 
        categoriaNombre: item.nombre 
      })}
      accessible={true}
      accessibilityLabel={item.nombre}
      accessibilityHint="Toca para ver los productos"
      accessibilityActions={[
        { name: 'editar', label: 'Editar categoría' },
        { name: 'eliminar', label: 'Eliminar categoría' }
      ]}
      onAccessibilityAction={(event) => {
        switch (event.nativeEvent.actionName) {
          case 'editar':
            navigation.navigate('EditarCategoria', { 
              categoriaId: item.id, 
              categoriaNombre: item.nombre 
            });
            break;
          case 'eliminar':
            handleEliminarCategoria(item.id, item.nombre);
            break;
        }
      }}
      onLongPress={() => navigation.navigate('EditarCategoria', { 
        categoriaId: item.id, 
        categoriaNombre: item.nombre 
      })}
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
        style={styles.header}
        accessible={true}
        accessibilityRole="header"
      >
        <Text style={styles.titulo}>Inventario Casa</Text>
        {householdName ? <Text style={styles.householdName}>Hogar: {householdName}</Text> : null}
        {householdCode ? <Text style={styles.codigo}>Código hogar: {householdCode}</Text> : null}
      </View>

      {categorias.length === 0 ? (
        <View style={styles.emptyContainer}>
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
          data={categorias}
          renderItem={renderCategoria}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.lista}
          accessible={false}
          accessibilityLabel={`Lista de ${categorias.length} categorías`}
        />
      )}

      <TouchableOpacity
        style={styles.botonFlotante}
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
    paddingTop: 60,
  },
  titulo: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
  },
  codigo: {
    marginTop: 6,
    color: '#E6F0FF',
    fontSize: 13,
    fontWeight: '500',
  },
  householdName: {
    marginTop: 6,
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
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
