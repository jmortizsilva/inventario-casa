import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// Configuración de Firebase desde variables de entorno
// Estas variables se configuran en EAS Secrets para builds en la nube
// y en el archivo firebase-config.js para desarrollo local
const firebaseConfig = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID
};

// Inicializar Firebase
const app = initializeApp(firebaseConfig);

// Inicializar Firestore (sin persistencia offline para React Native)
const db = getFirestore(app);
const auth = getAuth(app);

export { db, auth };
