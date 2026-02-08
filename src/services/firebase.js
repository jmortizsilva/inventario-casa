import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

// Importa la configuración (crearás este archivo con tus credenciales)
import { firebaseConfig } from '../../firebase-config';

// Inicializar Firebase
const app = initializeApp(firebaseConfig);

// Inicializar Firestore (sin persistencia offline para React Native)
const db = getFirestore(app);

export { db };
