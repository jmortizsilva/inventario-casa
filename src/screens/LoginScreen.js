import React, { useEffect, useMemo, useState } from 'react';
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
import * as WebBrowser from 'expo-web-browser';
import * as Google from 'expo-auth-session/providers/google';
import { useAuth } from '../contexts/AuthContext';

WebBrowser.maybeCompleteAuthSession();

export default function LoginScreen() {
  const { signInWithGoogleToken, loading, error } = useAuth();
  const [joinCode, setJoinCode] = useState('');
  const [householdName, setHouseholdName] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const isConfigured = useMemo(() => {
    return Boolean(
      process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID ||
      process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID ||
      process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID
    );
  }, []);

  const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
    iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
    androidClientId: process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID,
    webClientId: process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
  });

  useEffect(() => {
    const doSignIn = async () => {
      if (response?.type !== 'success') {
        return;
      }

      const idToken = response.params?.id_token;
      if (!idToken) {
        Alert.alert('Error', 'No se recibió token de Google');
        return;
      }

      try {
        setSubmitting(true);
        await signInWithGoogleToken(
          idToken,
          joinCode.trim().toUpperCase(),
          householdName.trim()
        );
      } catch (signInError) {
        Alert.alert(
          'Error de autenticación',
          signInError?.message || 'No se pudo iniciar sesión con Google'
        );
      } finally {
        setSubmitting(false);
      }
    };

    doSignIn();
  }, [response]);

  useEffect(() => {
    if (error) {
      Alert.alert('Error', error);
    }
  }, [error]);

  const handleGoogleLogin = async () => {
    if (!isConfigured) {
      Alert.alert(
        'Configuración pendiente',
        'Faltan variables de entorno de Google OAuth (iOS/Android/Web Client ID).'
      );
      return;
    }

    try {
      await promptAsync();
    } catch (promptError) {
      Alert.alert(
        'Error',
        promptError?.message || 'No se pudo abrir el inicio de sesión de Google'
      );
    }
  };

  const blocked = loading || submitting;

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.card}>
        <Text style={styles.title}>Inventario Casa</Text>
        <Text style={styles.subtitle}>Accede con Google y comparte hogar por código</Text>

        <Text style={styles.label}>Código de hogar (opcional)</Text>
        <TextInput
          style={styles.input}
          value={joinCode}
          onChangeText={(value) => setJoinCode(value.toUpperCase())}
          autoCapitalize="characters"
          maxLength={8}
          editable={!blocked}
          placeholder="Ej: A1B2C3"
          placeholderTextColor="#888"
          accessibilityLabel="Código de hogar opcional"
        />

        <Text style={styles.label}>Nombre del hogar (si creas uno nuevo)</Text>
        <TextInput
          style={styles.input}
          value={householdName}
          onChangeText={setHouseholdName}
          autoCapitalize="words"
          maxLength={40}
          editable={!blocked}
          placeholder="Ej: Josonica"
          placeholderTextColor="#888"
          accessibilityLabel="Nombre opcional del hogar"
        />

        <TouchableOpacity
          style={[styles.button, blocked && styles.buttonDisabled]}
          onPress={handleGoogleLogin}
          disabled={blocked || !request}
          accessibilityRole="button"
          accessibilityLabel="Continuar con Google"
        >
          {blocked ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Continuar con Google</Text>
          )}
        </TouchableOpacity>

        <Text style={styles.helpText}>
          Si no introduces código, se crea un hogar nuevo automáticamente.
        </Text>
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
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: '#007AFF',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 15,
    color: '#444',
    marginBottom: 20,
  },
  label: {
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 8,
    color: '#333',
  },
  input: {
    borderWidth: 2,
    borderColor: '#007AFF',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    marginBottom: 16,
    color: '#111',
  },
  button: {
    backgroundColor: '#007AFF',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 50,
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 16,
  },
  helpText: {
    marginTop: 14,
    color: '#666',
    fontSize: 13,
    lineHeight: 18,
  },
});
