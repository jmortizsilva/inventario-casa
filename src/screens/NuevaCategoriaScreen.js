import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  AccessibilityInfo,
  Platform,
  KeyboardAvoidingView,
  ScrollView
} from 'react-native';
import { addCategory } from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function NuevaCategoriaScreen({ navigation }) {
  const { householdId } = useAuth();
  const [nombre, setNombre] = useState('');
  const [nombreDefaultValue, setNombreDefaultValue] = useState('');
  const [nombreInputVersion, setNombreInputVersion] = useState(0);
  const [guardando, setGuardando] = useState(false);
  const inputRef = useRef(null);
  const nombreValueRef = useRef('');

  const getNombreValue = () => nombreValueRef.current;

  const resetNombreInput = (nextDefaultValue = '') => {
    nombreValueRef.current = nextDefaultValue;
    setNombre(nextDefaultValue);
    setNombreDefaultValue(nextDefaultValue);
    setNombreInputVersion((current) => current + 1);
  };

  const handleGuardar = async () => {
    const nombreActual = getNombreValue().trim();

    if (!nombreActual) {
      Alert.alert('Error', 'El nombre de la categoría no puede estar vacío');
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility('Error: nombre vacío');
      }
      return;
    }

    setGuardando(true);
    const result = await addCategory(householdId, nombreActual);
    setGuardando(false);

    if (result.success) {
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(`Categoría ${nombreActual} creada correctamente`);
      }
      resetNombreInput('');
      navigation.goBack();
    } else {
      Alert.alert('Error', 'No se pudo crear la categoría');
    }
  };

  useEffect(() => {
    navigation.setOptions({
      headerLeft: () => (
        <TouchableOpacity
          onPress={() => navigation.goBack()}
          disabled={guardando}
          accessibilityRole="button"
          accessibilityLabel="Cancelar"
          style={styles.headerButton}
        >
          <Text style={[styles.headerButtonText, guardando && styles.headerButtonDisabled]}>Cancelar</Text>
        </TouchableOpacity>
      ),
      headerRight: () => (
        <TouchableOpacity
          onPress={handleGuardar}
          disabled={guardando || !nombre.trim()}
          accessibilityRole="button"
          accessibilityLabel={guardando ? 'Guardando' : 'Guardar categoría'}
          style={styles.headerButton}
        >
          <Text
            style={[
              styles.headerButtonText,
              (guardando || !nombre.trim()) && styles.headerButtonDisabled,
            ]}
          >
            {guardando ? 'Guardando...' : 'Guardar'}
          </Text>
        </TouchableOpacity>
      ),
    });

    setTimeout(() => {
      inputRef.current?.focus();
    }, 500);
  }, [navigation, guardando, nombre]);

  return (
    <KeyboardAvoidingView 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.formulario}>
          <Text 
            style={styles.label}
            accessible={true}
            accessibilityRole="header"
          >
            Nombre de la categoría
          </Text>
          
          <TextInput
            key={`nombre-${nombreInputVersion}`}
            ref={inputRef}
            style={styles.input}
            defaultValue={nombreDefaultValue}
            onChangeText={(text) => {
              nombreValueRef.current = text;
              setNombre(text);
            }}
            placeholder="Ej: Despensa, Refrigerador..."
            placeholderTextColor="#999"
            accessibilityLabel="Nombre de la categoría"
            accessibilityHint="Escribe el nombre para la nueva categoría"
            returnKeyType="done"
            onSubmitEditing={handleGuardar}
            editable={!guardando}
            maxLength={50}
          />

          <Text 
            style={styles.contador}
            accessible={true}
            accessibilityLabel={`${nombre.length} de 50 caracteres`}
          >
            {nombre.length}/50
          </Text>

        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    flexGrow: 1,
  },
  formulario: {
    padding: 20,
    paddingTop: 30,
  },
  label: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 10,
  },
  input: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 15,
    fontSize: 18,
    borderWidth: 2,
    borderColor: '#007AFF',
    minHeight: 50,
  },
  contador: {
    textAlign: 'right',
    color: '#666',
    marginTop: 5,
    fontSize: 14,
  },
  headerButton: {
    paddingHorizontal: 6,
    paddingVertical: 4,
  },
  headerButtonText: {
    fontSize: 17,
    color: '#fff',
    fontWeight: '600',
  },
  headerButtonDisabled: {
    opacity: 0.5,
  },
});
