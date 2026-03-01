import React from 'react';
import {
  Alert,
  Modal,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';

export default function AjustesScreen() {
  const [manualVisible, setManualVisible] = React.useState(false);
  const [migrating, setMigrating] = React.useState(false);
  const { householdCode, householdName, migrateLegacyDataNow, signOut } = useAuth();

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

  const handleImportarDatosAnteriores = async () => {
    if (migrating) {
      return;
    }

    setMigrating(true);
    const result = await migrateLegacyDataNow();
    setMigrating(false);

    if (!result.success) {
      Alert.alert('Importación', result.error || 'No se pudieron importar los datos antiguos.');
      return;
    }

    if (!result.migrated) {
      Alert.alert('Importación', 'No había datos antiguos pendientes para importar.');
      return;
    }

    Alert.alert(
      'Importación completada',
      `Se importaron ${result.categories || 0} categorías y ${result.products || 0} productos a este hogar.`
    );
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.screenTitle} accessibilityRole="header">
        Ajustes
      </Text>

      <View style={styles.card}>
        <Text style={styles.sectionTitle} accessibilityRole="header">Hogar</Text>

        <View
          style={styles.compactRow}
          accessible={true}
          accessibilityLabel={`Hogar: ${householdName || 'Sin nombre'}`}
        >
          <Text style={styles.compactRowText} accessible={false}>
            Hogar: {householdName || 'Sin nombre'}
          </Text>
        </View>

        <View
          style={styles.compactRow}
          accessible={true}
          accessibilityLabel={`Código: ${householdCode || 'Sin código'}`}
        >
          <Text style={styles.compactRowText} accessible={false}>
            Código: {householdCode || 'Sin código'}
          </Text>
        </View>

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
        <Text style={styles.sectionTitle} accessibilityRole="header">Ayuda</Text>
        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={handleImportarDatosAnteriores}
          accessibilityRole="button"
          accessibilityLabel="Importar datos anteriores"
        >
          <Text style={styles.secondaryButtonText}>
            {migrating ? 'Importando...' : 'Importar datos anteriores'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.secondaryButton}
          onPress={() => setManualVisible(true)}
          accessibilityRole="button"
          accessibilityLabel="Abrir manual"
        >
          <Text style={styles.secondaryButtonText}>Abrir manual</Text>
        </TouchableOpacity>
      </View>

      <TouchableOpacity
        style={styles.logoutButton}
        onPress={signOut}
        accessibilityRole="button"
        accessibilityLabel="Cerrar sesión"
      >
        <Text style={styles.logoutText}>Cerrar sesión</Text>
      </TouchableOpacity>

      <Modal
        visible={manualVisible}
        animationType="slide"
        onRequestClose={() => setManualVisible(false)}
      >
        <View style={styles.manualContainer}>
          <Text style={styles.manualTitle} accessibilityRole="header">Manual</Text>
          <ScrollView contentContainerStyle={styles.manualContent}>
            <Text style={styles.step}>1. Crea una categoría desde Inventario con el botón +.</Text>
            <Text style={styles.step}>2. Añade productos y define si van a lista automática o manual.</Text>
            <Text style={styles.step}>3. Usa la pestaña Compra para revisar y ajustar cantidades.</Text>
            <Text style={styles.step}>4. Comparte tu código de hogar para sincronizar con otra persona.</Text>
          </ScrollView>
          <TouchableOpacity
            style={styles.primaryButton}
            onPress={() => setManualVisible(false)}
            accessibilityRole="button"
            accessibilityLabel="Cerrar manual"
          >
            <Text style={styles.primaryButtonText}>Cerrar manual</Text>
          </TouchableOpacity>
        </View>
      </Modal>
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
  screenTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#111',
    marginBottom: 2,
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
  compactRow: {
    marginTop: 6,
    marginBottom: 2,
  },
  compactRowText: {
    fontSize: 16,
    color: '#111',
    fontWeight: '600',
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
  secondaryButton: {
    marginTop: 4,
    backgroundColor: '#007AFF',
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 44,
  },
  secondaryButtonText: {
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
  manualContainer: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    padding: 16,
    gap: 12,
  },
  manualTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#111',
  },
  manualContent: {
    paddingBottom: 10,
  },
});
