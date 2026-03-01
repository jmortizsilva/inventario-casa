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
import { updateCategory } from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function EditarCategoriaScreen({ route, navigation }) {
  const { householdId } = useAuth();
  const { categoriaId, categoriaNombre } = route.params;
  const [nombre, setNombre] = useState(categoriaNombre);
  const [guardando, setGuardando] = useState(false);
  const inputRef = useRef(null);
  const lastNombreEventCountRef = useRef(0);

  const handleNombreChange = (event) => {
    const { text, eventCount } = event.nativeEvent;

    if (
      typeof eventCount === 'number' &&
      eventCount < lastNombreEventCountRef.current
    ) {
      return;
    }

    if (typeof eventCount === 'number') {
      lastNombreEventCountRef.current = eventCount;
    }

    setNombre(text);
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
          accessibilityLabel={guardando ? 'Guardando' : 'Guardar cambios'}
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
      inputRef.current?.setSelection(0, categoriaNombre.length);
    }, 500);
  }, [navigation, guardando, nombre, categoriaNombre]);

  const handleGuardar = async () => {
    if (!nombre.trim()) {
      Alert.alert('Error', 'El nombre de la categoría no puede estar vacío');
      return;
    }

    if (nombre.trim() === categoriaNombre) {
      navigation.goBack();
      return;
    }

    setGuardando(true);
    const result = await updateCategory(householdId, categoriaId, nombre.trim());
    setGuardando(false);

    if (result.success) {
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(`Categoría actualizada a ${nombre}`);
      }
      navigation.goBack();
    } else {
      Alert.alert('Error', 'No se pudo actualizar la categoría');
    }
  };

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
            ref={inputRef}
            style={styles.input}
            value={nombre}
            onChange={handleNombreChange}
            placeholder="Nombre de la categoría"
            placeholderTextColor="#999"
            accessibilityLabel="Nombre de la categoría"
            accessibilityHint="Edita el nombre de la categoría"
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
