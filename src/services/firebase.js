import { initializeApp } from 'firebase/app';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getAuth, initializeAuth, getReactNativePersistence } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

let localFirebaseConfig = {};
try {
  localFirebaseConfig = require('../../firebase-config').firebaseConfig || {};
} catch (_) {
  localFirebaseConfig = {};
}

// Configuración de Firebase desde variables de entorno
// Estas variables se configuran en EAS Secrets para builds en la nube
// y en el archivo firebase-config.js para desarrollo local
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY || localFirebaseConfig.apiKey,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN || localFirebaseConfig.authDomain,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID || localFirebaseConfig.projectId,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET || localFirebaseConfig.storageBucket,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || localFirebaseConfig.messagingSenderId,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID || localFirebaseConfig.appId,
};

const requiredFirebaseFields = ['apiKey', 'authDomain', 'projectId', 'storageBucket', 'messagingSenderId', 'appId'];
const missingFirebaseFields = requiredFirebaseFields.filter((field) => !firebaseConfig[field]);

if (missingFirebaseFields.length > 0) {
  throw new Error(
    `Firebase mal configurado. Faltan campos: ${missingFirebaseFields.join(', ')}. ` +
    'Configura EXPO_PUBLIC_FIREBASE_* en EAS o define firebase-config.js'
  );
}

// Inicializar Firebase
const app = initializeApp(firebaseConfig);

// Inicializar Firestore (sin persistencia offline para React Native)
const db = getFirestore(app);

let auth;
try {
  auth = initializeAuth(app, {
    persistence: getReactNativePersistence(AsyncStorage),
  });
} catch (_) {
  auth = getAuth(app);
}

export { db, auth };
