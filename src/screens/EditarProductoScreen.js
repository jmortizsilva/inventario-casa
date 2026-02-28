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
    navigation.setOptions({ title: `Editar ${producto.nombre}` });
    setTimeout(() => {
      nombreRef.current?.focus();
      nombreRef.current?.setSelection(0, producto.nombre.length);
    }, 500);
  }, []);

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
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.formulario}>
          <View style={styles.campo}>
            <View style={styles.switchRow}>
              <Text 
                style={styles.label}
                accessible={true}
                accessibilityRole="header"
              >
                Añadir automáticamente a la lista
              </Text>
              <Switch
                value={autoListaCompra}
                onValueChange={setAutoListaCompra}
                disabled={!nombre.trim() || guardando}
                accessibilityLabel="Conmutador de lista de compra automática"
              />
            </View>
          </View>

          {autoListaCompra ? (
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
              onChange={handleNombreChange}
              placeholder="Nombre del producto"
              placeholderTextColor="#999"
              accessibilityLabel="Nombre del producto"
              accessibilityHint="Edita el nombre del producto"
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
          ) : null}

          <View style={styles.campo}>
            <Text 
              style={styles.label}
              accessible={true}
              accessibilityRole="header"
            >
              Pasar a lista de compra con
            </Text>

            <View style={styles.pickerContainer}>
              <Picker
                selectedValue={umbralCompra}
                onValueChange={(itemValue) => setUmbralCompra(itemValue)}
                style={styles.picker}
                itemStyle={styles.pickerItem}
                accessibilityLabel="Seleccionar umbral para lista de compra"
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
              accessibilityLabel={guardando ? 'Guardando' : 'Guardar cambios'}
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
