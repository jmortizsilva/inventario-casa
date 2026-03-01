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
  Switch,
  KeyboardAvoidingView,
  ScrollView
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { updateProduct } from '../services/firestore';
import { useAuth } from '../contexts/AuthContext';

export default function EditarProductoScreen({ route, navigation }) {
  const { householdId } = useAuth();
  const { producto, categoriaId, categoriaNombre } = route.params;
  const [nombre, setNombre] = useState(producto.nombre);
  const [cantidad, setCantidad] = useState(producto.cantidad);
  const [umbralCompra, setUmbralCompra] = useState(producto.umbralCompra ?? 2);
  const [autoListaCompra, setAutoListaCompra] = useState(producto.autoListaCompra ?? true);
  const [guardando, setGuardando] = useState(false);
  const nombreRef = useRef(null);

  useEffect(() => {
    navigation.setOptions({
      title: `Editar ${producto.nombre}`,
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
  }, [navigation, producto.nombre, guardando, nombre]);

  const handleGuardar = async () => {
    if (!nombre.trim()) {
      Alert.alert('Error', 'El nombre del producto no puede estar vacío');
      return;
    }
    
    const umbralOriginal = producto.umbralCompra ?? 2;

    if (
      nombre.trim() === producto.nombre &&
      cantidad === producto.cantidad &&
      umbralCompra === umbralOriginal &&
      autoListaCompra === (producto.autoListaCompra ?? true)
    ) {
      navigation.goBack();
      return;
    }

    setGuardando(true);
    const result = await updateProduct(householdId, producto.id, {
      nombre: nombre.trim(),
      cantidad: cantidad,
      umbralCompra: umbralCompra,
      autoListaCompra: autoListaCompra
    });
    setGuardando(false);

    if (result.success) {
      if (Platform.OS === 'ios') {
        AccessibilityInfo.announceForAccessibility(
          autoListaCompra
            ? `Producto actualizado: ${nombre}, cantidad ${cantidad}. Lista de compra con ${umbralCompra} unidades o menos`
            : `Producto actualizado: ${nombre}, cantidad ${cantidad}. Sin lista automática`
        );
      }
      navigation.goBack();
    } else {
      Alert.alert('Error', 'No se pudo actualizar el producto');
    }
  };

  return (
    <KeyboardAvoidingView 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        <View style={styles.formulario}>
          <View style={styles.campo}>
            <Text 
              style={styles.label}
              accessible={false}
              importantForAccessibility="no"
            >
              Nombre del producto
            </Text>
            
            <TextInput
              ref={nombreRef}
              style={styles.input}
              value={nombre}
              onChangeText={setNombre}
              placeholder="Nombre del producto"
              placeholderTextColor="#999"
              accessibilityLabel="Nombre del producto, campo de edición"
              accessibilityHint="Edita el nombre del producto"
              returnKeyType="next"
              onSubmitEditing={handleGuardar}
              editable={!guardando}
              blurOnSubmit={false}
              maxLength={50}
            />

            <Text 
              style={styles.contador}
              accessible={false}
              importantForAccessibility="no"
              accessibilityLabel={`${nombre.length} de 50 caracteres`}
            >
              {nombre.length}/50
            </Text>
          </View>

          <View style={styles.campo}>
            <Text 
              style={styles.label}
              accessible={false}
              importantForAccessibility="no"
            >
              Cantidad
            </Text>
            
            <View style={styles.pickerContainer}>
              <Picker
                selectedValue={cantidad}
                onValueChange={(itemValue) => setCantidad(itemValue)}
                style={styles.picker}
                itemStyle={styles.pickerItem}
                accessibilityLabel="Seleccionar cantidad"
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

          <View style={styles.campo}>
            <View style={styles.switchRow}>
              <Text
                style={styles.label}
                accessible={false}
                importantForAccessibility="no"
              >
                Añadir automáticamente a la lista
              </Text>
              <Switch
                value={autoListaCompra}
                onValueChange={setAutoListaCompra}
                disabled={!nombre.trim() || guardando}
                accessibilityLabel="Añadir automáticamente a la lista de compra"
              />
            </View>
          </View>

          {autoListaCompra ? (
            <View style={styles.campo}>
              <Text
                style={styles.label}
                accessible={false}
                importantForAccessibility="no"
              >
                Pasar a lista de compra con
              </Text>

              <View style={styles.pickerContainer}>
                <Picker
                  selectedValue={umbralCompra}
                  onValueChange={(itemValue) => setUmbralCompra(itemValue)}
                  style={styles.picker}
                  itemStyle={styles.pickerItem}
                  accessibilityLabel="Pasar a lista de compra con"
                  accessibilityHint="Desliza arriba o abajo para elegir con cuántas unidades pasa a la lista"
                  enabled={!guardando}
                >
                  {Array.from({ length: 21 }, (_, i) => i).map(num => (
                    <Picker.Item 
                      key={num} 
                      label={`${num} ${num === 1 ? 'unidad' : 'unidades'} o menos`} 
                      value={num}
                    />
                  ))}
                </Picker>
              </View>
            </View>
          ) : null}

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
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
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
