import React, { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';

export default function SeleccionHogarScreen() {
  const {
    householdName,
    householdCode,
    continueWithCurrentHousehold,
    joinHouseholdByCode,
    createAdditionalHousehold,
  } = useAuth();

  const [joinCode, setJoinCode] = useState('');
  const [newHouseholdName, setNewHouseholdName] = useState('');
  const [busy, setBusy] = useState(false);

  const handleContinue = async () => {
    if (busy) {
      return;
    }

    setBusy(true);
    try {
      await continueWithCurrentHousehold();
    } finally {
      setBusy(false);
    }
  };

  const handleJoin = async () => {
    const normalized = joinCode.trim().toUpperCase();
    if (!normalized) {
      Alert.alert('Código requerido', 'Introduce un código de hogar para unirte.');
      return;
    }

    setBusy(true);
    try {
      await joinHouseholdByCode(normalized);
    } catch (error) {
      Alert.alert('No se pudo unir', error?.message || 'Código no válido');
    } finally {
      setBusy(false);
    }
  };

  const handleCreate = async () => {
    setBusy(true);
    try {
      await createAdditionalHousehold(newHouseholdName.trim());
    } catch (error) {
      Alert.alert('No se pudo crear', error?.message || 'Inténtalo de nuevo');
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.card}>
        <Text style={styles.title} accessibilityRole="header">
          Elige hogar
        </Text>

        {householdName ? (
          <View style={styles.currentBox}>
            <Text style={styles.currentTitle}>Hogar actual</Text>
            <Text style={styles.currentText}>Nombre: {householdName}</Text>
            <Text style={styles.currentText}>Código: {householdCode || 'Sin código'}</Text>

            <TouchableOpacity
              style={[styles.primaryButton, busy && styles.disabled]}
              onPress={handleContinue}
              disabled={busy}
              accessibilityRole="button"
              accessibilityLabel="Continuar con hogar actual"
            >
              {busy ? <ActivityIndicator color="#fff" /> : <Text style={styles.primaryButtonText}>Continuar con este hogar</Text>}
            </TouchableOpacity>
          </View>
        ) : null}

        <Text style={styles.sectionTitle}>Unirme a otro hogar</Text>
        <TextInput
          style={styles.input}
          value={joinCode}
          onChangeText={(value) => setJoinCode(value.toUpperCase())}
          autoCapitalize="characters"
          maxLength={8}
          editable={!busy}
          placeholder="Ej: A1B2C3"
          placeholderTextColor="#888"
          accessibilityLabel="Código para unirme a un hogar"
        />

        <TouchableOpacity
          style={[styles.secondaryButton, busy && styles.disabled]}
          onPress={handleJoin}
          disabled={busy}
          accessibilityRole="button"
          accessibilityLabel="Unirme con código"
        >
          <Text style={styles.secondaryButtonText}>Unirme con código</Text>
        </TouchableOpacity>

        <Text style={styles.sectionTitle}>Crear otro hogar</Text>
        <TextInput
          style={styles.input}
          value={newHouseholdName}
          onChangeText={setNewHouseholdName}
          autoCapitalize="words"
          maxLength={40}
          editable={!busy}
          placeholder="Ej: Mi casa"
          placeholderTextColor="#888"
          accessibilityLabel="Nombre para el nuevo hogar"
        />

        <TouchableOpacity
          style={[styles.secondaryButton, busy && styles.disabled]}
          onPress={handleCreate}
          disabled={busy}
          accessibilityRole="button"
          accessibilityLabel="Crear nuevo hogar"
        >
          <Text style={styles.secondaryButtonText}>Crear nuevo hogar</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    justifyContent: 'center',
    padding: 20,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 6,
    elevation: 4,
    gap: 10,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: '#007AFF',
    marginBottom: 6,
  },
  currentBox: {
    backgroundColor: '#F0F7FF',
    borderRadius: 12,
    padding: 12,
    marginBottom: 4,
  },
  currentTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#1D5FBF',
    marginBottom: 4,
  },
  currentText: {
    fontSize: 15,
    color: '#1B1B1B',
    marginBottom: 2,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#333',
    marginTop: 4,
  },
  input: {
    borderWidth: 2,
    borderColor: '#007AFF',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: '#111',
  },
  primaryButton: {
    marginTop: 10,
    backgroundColor: '#007AFF',
    borderRadius: 12,
    minHeight: 46,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  secondaryButton: {
    backgroundColor: '#005FCC',
    borderRadius: 12,
    minHeight: 46,
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryButtonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '700',
  },
  disabled: {
    opacity: 0.7,
  },
});
