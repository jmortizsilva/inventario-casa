import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';

// Pantallas
import CategoriasScreen from './src/screens/CategoriasScreen';
import ProductosScreen from './src/screens/ProductosScreen';
import NuevaCategoriaScreen from './src/screens/NuevaCategoriaScreen';
import EditarCategoriaScreen from './src/screens/EditarCategoriaScreen';
import NuevoProductoScreen from './src/screens/NuevoProductoScreen';
import EditarProductoScreen from './src/screens/EditarProductoScreen';

const Stack = createNativeStackNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <StatusBar style="light" />
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
    </NavigationContainer>
  );
}
