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
import { Picker } from '@react-native-picker/picker';
import { addProduct } from '../services/firestore';

export default function NuevoProductoScreen({ route, navigation }) {
  const { categoriaId, categoriaNombre } = route.params;
  const [nombre, setNombre] = useState('');
  const [cantidad, setCantidad] = useState(0);
  const [guardando, setGuardando] = useState(false);
  const nombreRef = useRef(null);

  useEffect(() => {
    navigation.setOptions({ title: `Nuevo en ${categoriaNombre}` });
    setTimeout(() => {
      nombreRef.current?.focus();
    }, 500);
  }, []);

  const handleGuardar = async () => {
    if (!nombre.trim()) {
      Alert.alert('Error', 'El nombre del producto no puede estar vacío');
      return;
    }

    setGuardando(true);
    const result = await addProduct(nombre.trim(), String(cantidad), categoriaId);
    setGuardando(false);

    if (result.success) {
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(
          `Producto ${nombre} añadido con cantidad ${cantidad}`
        );
      }
      navigation.goBack();
    } else {
      Alert.alert('Error', 'No se pudo crear el producto');
    }
  };

  return (
    <KeyboardAvoidingView 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.formulario}>
          <View style={styles.campo}>
            <Text 
              style={styles.label}
              accessible={true}
              accessibilityRole="header"
            >
              Nombre del producto
            </Text>
            
            <TextInput
              ref={nombreRef}
              style={styles.input}
              value={nombre}
              onChangeText={setNombre}
              placeholder="Ej: Arroz, Leche, Pan..."
              placeholderTextColor="#999"
              accessibilityLabel="Nombre del producto"
              accessibilityHint="Escribe el nombre del producto"
              returnKeyType="next"
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

          <View style={styles.campo}>
            <Text 
              style={styles.label}
              accessible={true}
              accessibilityRole="header"
            >
              Cantidad inicial
            </Text>
            
            <View style={styles.pickerContainer}>
              <Picker
                selectedValue={cantidad}
                onValueChange={(itemValue) => setCantidad(itemValue)}
                style={styles.picker}
                itemStyle={styles.pickerItem}
                accessibilityLabel="Seleccionar cantidad inicial"
                accessibilityHint="Desliza arriba o abajo para cambiar la cantidad"
                enabled={!guardando}
              >
                {Array.from({ length: 100 }, (_, i) => i).map(num => (
                  <Picker.Item 
                    key={num} 
                    label={`${num} ${num === 1 ? 'unidad' : 'unidades'}`} 
                    value={num}
                  />
                ))}
              </Picker>
            </View>
          </View>

          <View style={styles.botonesContainer}>
            <TouchableOpacity
              style={[styles.boton, styles.botonCancelar]}
              onPress={() => navigation.goBack()}
              disabled={guardando}
              accessible={true}
              accessibilityLabel="Cancelar"
              accessibilityRole="button"
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
              accessibilityLabel={guardando ? 'Guardando' : 'Guardar producto'}
              accessibilityRole="button"
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
  campo: {
    marginBottom: 25,
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
  pickerContainer: {
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#007AFF',
    overflow: 'hidden',
  },
  picker: {
    height: 150,
  },
  pickerItem: {
    fontSize: 20,
    height: 150,
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
