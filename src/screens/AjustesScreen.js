import React from 'react';
import {
  Alert,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';

export default function AjustesScreen() {
  const { householdCode, householdName, signOut } = useAuth();

  const handleCompartirHogar = async () => {
    if (!householdCode) {
      Alert.alert('Sin código', 'Todavía no hay código de hogar disponible.');
      return;
    }

    try {
      await Share.share({
        title: 'Invitación a Inventario Casa',
        message: `Únete a mi hogar en Inventario Casa con este código: ${householdCode}`,
      });
    } catch (error) {
      Alert.alert('Error', 'No se pudo abrir el menú de compartir');
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>Hogar</Text>
        <Text style={styles.rowLabel}>Nombre</Text>
        <Text style={styles.rowValue}>{householdName || 'Sin nombre'}</Text>

        <Text style={styles.rowLabel}>Código</Text>
        <Text style={styles.rowValue}>{householdCode || 'Sin código'}</Text>

        <TouchableOpacity
          style={styles.primaryButton}
          onPress={handleCompartirHogar}
          accessibilityRole="button"
          accessibilityLabel="Compartir hogar"
        >
          <Text style={styles.primaryButtonText}>Compartir hogar</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionTitle}>Tutorial rápido</Text>
        <Text style={styles.step}>1. Crea una categoría desde Inventario con el botón +.</Text>
        <Text style={styles.step}>2. Añade productos y define si van a lista automática o manual.</Text>
        <Text style={styles.step}>3. Usa la pestaña Compra para revisar y ajustar cantidades.</Text>
        <Text style={styles.step}>4. Comparte tu código de hogar para sincronizar con otra persona.</Text>
      </View>

      <TouchableOpacity
        style={styles.logoutButton}
        onPress={signOut}
        accessibilityRole="button"
        accessibilityLabel="Cerrar sesión"
      >
        <Text style={styles.logoutText}>Cerrar sesión</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    padding: 16,
    gap: 14,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#222',
    marginBottom: 10,
  },
  rowLabel: {
    fontSize: 13,
    color: '#666',
    marginTop: 4,
  },
  rowValue: {
    fontSize: 16,
    color: '#111',
    fontWeight: '600',
    marginBottom: 6,
  },
  primaryButton: {
    marginTop: 10,
    backgroundColor: '#1F8B4C',
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 44,
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  step: {
    fontSize: 14,
    color: '#333',
    lineHeight: 22,
    marginBottom: 6,
  },
  logoutButton: {
    backgroundColor: '#005FCC',
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 44,
    marginBottom: 20,
  },
  logoutText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
});
