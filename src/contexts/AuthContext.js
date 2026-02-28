import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithCredential,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  where,
} from 'firebase/firestore';
import { auth, db } from '../services/firebase';

const AuthContext = createContext(null);

const normalizeCode = (code) => (code || '').trim().toUpperCase();

const generateInviteCode = () =>
  Math.random().toString(36).substring(2, 8).toUpperCase();

const findHouseholdByCode = async (joinCode) => {
  const normalized = normalizeCode(joinCode);
  if (!normalized) return null;

  const q = query(
    collection(db, 'households'),
    where('inviteCode', '==', normalized),
    limit(1)
  );
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;

  return snapshot.docs[0];
};

const createHouseholdForUser = async (user, requestedHouseholdName = '') => {
  let inviteCode = generateInviteCode();
  let existing = await findHouseholdByCode(inviteCode);

  while (existing) {
    inviteCode = generateInviteCode();
    existing = await findHouseholdByCode(inviteCode);
  }

  const householdName = (requestedHouseholdName || '').trim() ||
    (user.displayName ? `Hogar de ${user.displayName}` : 'Mi Hogar');

  const householdRef = await addDoc(collection(db, 'households'), {
    name: householdName,
    inviteCode,
    ownerUid: user.uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  return {
    householdId: householdRef.id,
    inviteCode,
  };
};

const ensureUserHousehold = async (user, joinCode = '', householdName = '') => {
  const userRef = doc(db, 'users', user.uid);
  const userSnapshot = await getDoc(userRef);

  if (userSnapshot.exists()) {
    const userData = userSnapshot.data();
    if (userData.householdId) {
      const householdRef = doc(db, 'households', userData.householdId);
      const householdSnapshot = await getDoc(householdRef);
      const householdName = householdSnapshot.exists()
        ? householdSnapshot.data().name || null
        : null;

      return {
        householdId: userData.householdId,
        inviteCode: userData.inviteCode || null,
        householdName,
      };
    }
  }

  let householdId;
  let inviteCode = null;

  const existingHousehold = await findHouseholdByCode(joinCode);

  if (joinCode && !existingHousehold) {
    throw new Error('Código de hogar no válido');
  }

  if (existingHousehold) {
    householdId = existingHousehold.id;
    inviteCode = existingHousehold.data().inviteCode || normalizeCode(joinCode);
    householdName = existingHousehold.data().name || null;
  } else {
    const created = await createHouseholdForUser(user, householdName);
    householdId = created.householdId;
    inviteCode = created.inviteCode;
    householdName = (householdName || '').trim() || (user.displayName ? `Hogar de ${user.displayName}` : 'Mi Hogar');
  }

  await setDoc(
    userRef,
    {
      uid: user.uid,
      email: user.email || null,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      householdId,
      inviteCode,
      updatedAt: serverTimestamp(),
      createdAt: userSnapshot.exists() ? userSnapshot.data().createdAt : serverTimestamp(),
    },
    { merge: true }
  );

  return { householdId, inviteCode, householdName };
};

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [householdId, setHouseholdId] = useState(null);
  const [householdCode, setHouseholdCode] = useState(null);
  const [householdName, setHouseholdName] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const pendingJoinCodeRef = useRef('');
  const pendingHouseholdNameRef = useRef('');

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      setError(null);

      if (!firebaseUser) {
        setUser(null);
        setHouseholdId(null);
        setHouseholdCode(null);
        setHouseholdName(null);
        setLoading(false);
        return;
      }

      try {
        const ensured = await ensureUserHousehold(
          firebaseUser,
          pendingJoinCodeRef.current,
          pendingHouseholdNameRef.current
        );

        pendingJoinCodeRef.current = '';
        pendingHouseholdNameRef.current = '';
        setUser(firebaseUser);
        setHouseholdId(ensured.householdId);
        setHouseholdCode(ensured.inviteCode || null);
        setHouseholdName(ensured.householdName || null);
      } catch (authError) {
        setError(authError.message || 'No se pudo preparar el hogar');
        await firebaseSignOut(auth);
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const signInWithGoogleToken = async (
    idToken,
    joinCode = '',
    householdName = ''
  ) => {
    setError(null);
    setLoading(true);

    try {
      pendingJoinCodeRef.current = joinCode;
      pendingHouseholdNameRef.current = householdName;
      const credential = GoogleAuthProvider.credential(idToken);
      await signInWithCredential(auth, credential);
    } catch (signInError) {
      pendingJoinCodeRef.current = '';
      pendingHouseholdNameRef.current = '';
      setLoading(false);
      throw signInError;
    }
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        householdId,
        householdCode,
        householdName,
        loading,
        error,
        signInWithGoogleToken,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth debe usarse dentro de AuthProvider');
  }
  return context;
};
