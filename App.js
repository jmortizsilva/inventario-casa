import React from 'react';
import { Platform } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createNativeBottomTabNavigator } from '@bottom-tabs/react-navigation';
import { StatusBar } from 'expo-status-bar';

import CategoriasScreen from './src/screens/CategoriasScreen';
import ProductosScreen from './src/screens/ProductosScreen';
import NuevaCategoriaScreen from './src/screens/NuevaCategoriaScreen';
import EditarCategoriaScreen from './src/screens/EditarCategoriaScreen';
import NuevoProductoScreen from './src/screens/NuevoProductoScreen';
import EditarProductoScreen from './src/screens/EditarProductoScreen';
import ListaCompraScreen from './src/screens/ListaCompraScreen';

const Stack = createNativeStackNavigator();
const Tab = createNativeBottomTabNavigator();

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
            tabBarIcon: () => (Platform.OS === 'ios' ? { sfSymbol: 'shippingbox.fill' } : null),
          }}
        />
        <Tab.Screen
          name="ListaCompra"
          component={ListaCompraScreen}
          options={{
            title: 'Lista de la Compra',
            tabBarLabel: 'Compra',
            tabBarIcon: () => (Platform.OS === 'ios' ? { sfSymbol: 'cart.fill' } : null),
          }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
