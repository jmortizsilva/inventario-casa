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

export default function NuevaCategoriaScreen({ navigation }) {
  const [nombre, setNombre] = useState('');
  const [guardando, setGuardando] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => {
    // Auto-focus en el campo de texto para accesibilidad
    setTimeout(() => {
      inputRef.current?.focus();
    }, 500);
  }, []);

  const handleGuardar = async () => {
    if (!nombre.trim()) {
      Alert.alert('Error', 'El nombre de la categoría no puede estar vacío');
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility('Error: nombre vacío');
      }
      return;
    }

    setGuardando(true);
    const result = await addCategory(nombre.trim());
    setGuardando(false);

    if (result.success) {
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(`Categoría ${nombre} creada correctamente`);
      }
      navigation.goBack();
    } else {
      Alert.alert('Error', 'No se pudo crear la categoría');
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
            onChangeText={setNombre}
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

          <View style={styles.botonesContainer}>
            <TouchableOpacity
              style={[styles.boton, styles.botonCancelar]}
              onPress={() => navigation.goBack()}
              disabled={guardando}
              accessible={true}
              accessibilityLabel="Cancelar"
              accessibilityRole="button"
              accessibilityHint="Descartar y volver atrás"
            >
              <Text style={styles.botonTextoCancelar}>Cancelar</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.boton, 
                styles.botonGuardar,
                guardando && styles.botonDeshabilitado
              ]}
              onPress={handleGuardar}
              disabled={guardando || !nombre.trim()}
              accessible={true}
              accessibilityLabel={guardando ? 'Guardando' : 'Guardar categoría'}
              accessibilityRole="button"
              accessibilityHint="Guardar la nueva categoría"
              accessibilityState={{ disabled: guardando || !nombre.trim() }}
            >
              <Text style={styles.botonTextoGuardar}>
                {guardando ? 'Guardando...' : 'Guardar'}
              </Text>
            </TouchableOpacity>
          </View>
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
  botonesContainer: {
    flexDirection: 'row',
    marginTop: 30,
    gap: 10,
  },
  boton: {
    flex: 1,
    padding: 18,
    borderRadius: 12,
    alignItems: 'center',
    minHeight: 56,
    justifyContent: 'center',
  },
  botonCancelar: {
    backgroundColor: '#fff',
    borderWidth: 2,
    borderColor: '#FF3B30',
  },
  botonTextoCancelar: {
    fontSize: 18,
    fontWeight: '600',
    color: '#FF3B30',
  },
  botonGuardar: {
    backgroundColor: '#007AFF',
  },
  botonTextoGuardar: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  botonDeshabilitado: {
    backgroundColor: '#ccc',
  },
});
