import React from 'react';
import { Text } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';

// Pantallas
import CategoriasScreen from './src/screens/CategoriasScreen';
import ProductosScreen from './src/screens/ProductosScreen';
import NuevaCategoriaScreen from './src/screens/NuevaCategoriaScreen';
import EditarCategoriaScreen from './src/screens/EditarCategoriaScreen';
import NuevoProductoScreen from './src/screens/NuevoProductoScreen';
import EditarProductoScreen from './src/screens/EditarProductoScreen';
import ListaCompraScreen from './src/screens/ListaCompraScreen';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

// Stack Navigator para el flujo del Inventario
function InventarioStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: {
          backgroundColor: '#007AFF',
        },
        headerTintColor: '#fff',
        headerTitleStyle: {
          fontWeight: 'bold',
          fontSize: 20,
        },
        headerBackTitle: 'Atrás',
        animation: 'slide_from_right',
      }}
    >
      <Stack.Screen 
        name="Categorias" 
        component={CategoriasScreen}
        options={{
          headerShown: false,
        }}
      />
      <Stack.Screen 
        name="Productos" 
        component={ProductosScreen}
        options={({ route }) => ({ 
          title: route.params?.categoriaNombre || 'Productos' 
        })}
      />
      <Stack.Screen 
        name="NuevaCategoria" 
        component={NuevaCategoriaScreen}
        options={{
          title: 'Nueva Categoría',
          presentation: 'modal',
        }}
      />
      <Stack.Screen 
        name="EditarCategoria" 
        component={EditarCategoriaScreen}
        options={{
          title: 'Editar Categoría',
          presentation: 'modal',
        }}
      />
      <Stack.Screen 
        name="NuevoProducto" 
        component={NuevoProductoScreen}
        options={{
          title: 'Nuevo Producto',
          presentation: 'modal',
        }}
      />
      <Stack.Screen 
        name="EditarProducto" 
        component={EditarProductoScreen}
        options={{
          title: 'Editar Producto',
          presentation: 'modal',
        }}
      />
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <NavigationContainer>
      <StatusBar style="light" />
      <Tab.Navigator
        screenOptions={{
          tabBarActiveTintColor: '#007AFF',
          tabBarInactiveTintColor: '#8E8E93',
          tabBarStyle: {
            backgroundColor: '#FFFFFF',
            borderTopColor: '#E5E5EA',
            borderTopWidth: 1,
            paddingTop: 5,
            paddingBottom: 5,
            height: 60,
          },
          tabBarLabelStyle: {
            fontSize: 12,
            fontWeight: '600',
          },
          headerStyle: {
            backgroundColor: '#007AFF',
          },
          headerTintColor: '#fff',
          headerTitleStyle: {
            fontWeight: 'bold',
            fontSize: 20,
          },
        }}
      >
        <Tab.Screen 
          name="InventarioTab" 
          component={InventarioStack}
          options={{
            title: 'Inventario',
            headerShown: false,
            tabBarLabel: 'Inventario',
            tabBarAccessibilityLabel: 'Inventario, navegar por categorías y productos',
            tabBarIcon: () => <Text style={{ fontSize: 24 }}>📦</Text>,
          }}
        />
        <Tab.Screen 
          name="ListaCompra" 
          component={ListaCompraScreen}
          options={{
            title: 'Lista de la Compra',
            tabBarLabel: 'Compra',
            tabBarAccessibilityLabel: 'Lista de la compra, productos con pocas unidades',
            tabBarIcon: () => <Text style={{ fontSize: 24 }}>🛒</Text>,
          }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
