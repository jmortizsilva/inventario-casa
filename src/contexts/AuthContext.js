import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithCredential,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import {
  collection,
  doc,
  getDoc,
  arrayUnion,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';
import { auth, db } from '../services/firebase';
import { migrateLegacyDataToHousehold } from '../services/firestore';

const AuthContext = createContext(null);

const normalizeCode = (code) => (code || '').trim().toUpperCase();

const findHouseholdByCode = async (joinCode) => {
  const normalized = normalizeCode(joinCode);
  if (!normalized) return null;

  const inviteRef = doc(db, 'householdInvites', normalized);
  const inviteSnapshot = await getDoc(inviteRef);
  if (!inviteSnapshot.exists()) return null;

  const householdId = inviteSnapshot.data().householdId || null;
  if (!householdId) return null;

  return {
    householdId,
    inviteCode: normalized,
    householdName: inviteSnapshot.data().householdName || null,
  };
};

const getHouseholdNameById = async (householdId) => {
  if (!householdId) return null;
  const snapshot = await getDoc(doc(db, 'households', householdId));
  if (!snapshot.exists()) return null;
  return snapshot.data().name || null;
};

const createHouseholdForUser = async (user, requestedHouseholdName = '') => {
  const householdRef = doc(collection(db, 'households'));
  const inviteCode = householdRef.id.slice(0, 6).toUpperCase();

  const householdName = (requestedHouseholdName || '').trim() ||
    (user.displayName ? `Hogar de ${user.displayName}` : 'Mi Hogar');

  await setDoc(householdRef, {
    name: householdName,
    inviteCode,
    ownerUid: user.uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  await setDoc(doc(db, 'householdInvites', inviteCode), {
    householdId: householdRef.id,
    ownerUid: user.uid,
    householdName,
    createdAt: serverTimestamp(),
  });

  return {
    householdId: householdRef.id,
    inviteCode,
  };
};

const ensureUserHousehold = async (user) => {
  const userRef = doc(db, 'users', user.uid);
  const userSnapshot = await getDoc(userRef);

  if (!userSnapshot.exists()) {
    await setDoc(
      userRef,
      {
        uid: user.uid,
        email: user.email || null,
        displayName: user.displayName || null,
        photoURL: user.photoURL || null,
        householdId: null,
        inviteCode: null,
        householdName: null,
        householdIds: [],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    return {
      householdId: null,
      inviteCode: null,
      householdName: null,
      hasHousehold: false,
      hadLegacyMigration: false,
    };
  }

  const userData = userSnapshot.data();

  if (!userData.householdId) {
    return {
      householdId: null,
      inviteCode: null,
      householdName: null,
      hasHousehold: false,
      hadLegacyMigration: Boolean(userData.legacyMigratedAt),
    };
  }

  if (!userData.legacyMigratedAt) {
    const migration = await migrateLegacyDataToHousehold(user.uid, userData.householdId);

    if (migration.success) {
      await setDoc(
        userRef,
        {
          legacyMigratedAt: serverTimestamp(),
          legacyMigration: {
            migrated: migration.migrated,
            categories: migration.categories || 0,
            products: migration.products || 0,
          },
        },
        { merge: true }
      );
    }
  }

  return {
    householdId: userData.householdId,
    inviteCode: userData.inviteCode || null,
    householdName: userData.householdName || (await getHouseholdNameById(userData.householdId)),
    hasHousehold: true,
    hadLegacyMigration: Boolean(userData.legacyMigratedAt),
  };
};

const assignHouseholdToUser = async (user, household) => {
  const userRef = doc(db, 'users', user.uid);

  await setDoc(
    userRef,
    {
      uid: user.uid,
      email: user.email || null,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      householdId: household.householdId,
      inviteCode: household.inviteCode || null,
      householdName: household.householdName || null,
      householdIds: arrayUnion(household.householdId),
      updatedAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    },
    { merge: true }
  );
};

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [householdId, setHouseholdId] = useState(null);
  const [householdCode, setHouseholdCode] = useState(null);
  const [householdName, setHouseholdName] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [requiresHouseholdChoice, setRequiresHouseholdChoice] = useState(false);
  const signInFreshRef = useRef(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        setUser(null);
        setHouseholdId(null);
        setHouseholdCode(null);
        setHouseholdName(null);
        setRequiresHouseholdChoice(false);
        signInFreshRef.current = false;
        setLoading(false);
        return;
      }

      try {
        setError(null);
        const ensured = await ensureUserHousehold(firebaseUser);
        setUser(firebaseUser);

        if (!ensured.hasHousehold) {
          setHouseholdId(null);
          setHouseholdCode(null);
          setHouseholdName(null);
          setRequiresHouseholdChoice(true);
        } else {
          setHouseholdId(ensured.householdId);
          setHouseholdCode(ensured.inviteCode || null);
          setHouseholdName(ensured.householdName || null);
          setRequiresHouseholdChoice(signInFreshRef.current);
        }
      } catch (authError) {
        setError(authError?.message || 'No se pudo preparar la sesión');
        await firebaseSignOut(auth);
      } finally {
        signInFreshRef.current = false;
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const signInWithGoogleToken = async (idToken) => {
    setError(null);
    setLoading(true);

    try {
      signInFreshRef.current = true;
      const credential = GoogleAuthProvider.credential(idToken);
      await signInWithCredential(auth, credential);
    } catch (signInError) {
      signInFreshRef.current = false;
      setLoading(false);
      throw signInError;
    }
  };

  const continueWithCurrentHousehold = async () => {
    setRequiresHouseholdChoice(false);
  };

  const joinHouseholdByCode = async (joinCode) => {
    if (!user) {
      throw new Error('No hay sesión iniciada');
    }

    const existingHousehold = await findHouseholdByCode(joinCode);

    if (!existingHousehold) {
      throw new Error('Código de hogar no válido');
    }

    const target = {
      householdId: existingHousehold.householdId,
      inviteCode: existingHousehold.inviteCode,
      householdName: existingHousehold.householdName || 'Hogar compartido',
    };

    await assignHouseholdToUser(user, target);

    let finalHouseholdName = target.householdName;
    try {
      const resolvedHouseholdName = await getHouseholdNameById(target.householdId);
      if (resolvedHouseholdName) {
        finalHouseholdName = resolvedHouseholdName;
      }
    } catch (_) {
      finalHouseholdName = target.householdName;
    }

    setHouseholdId(target.householdId);
    setHouseholdCode(target.inviteCode || null);
    setHouseholdName(finalHouseholdName || null);
    setRequiresHouseholdChoice(false);
  };

  const createAdditionalHousehold = async (requestedHouseholdName = '') => {
    if (!user) {
      throw new Error('No hay sesión iniciada');
    }

    const created = await createHouseholdForUser(user, requestedHouseholdName);
    const resolvedName = (requestedHouseholdName || '').trim() || (user.displayName ? `Hogar de ${user.displayName}` : 'Mi Hogar');
    const target = {
      householdId: created.householdId,
      inviteCode: created.inviteCode,
      householdName: resolvedName,
    };

    await assignHouseholdToUser(user, target);
    setHouseholdId(target.householdId);
    setHouseholdCode(target.inviteCode || null);
    setHouseholdName(target.householdName || null);
    setRequiresHouseholdChoice(false);
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
  };

  const migrateLegacyDataNow = async () => {
    if (!user?.uid || !householdId) {
      return { success: false, error: 'No hay sesión o hogar activo' };
    }

    const result = await migrateLegacyDataToHousehold(user.uid, householdId);

    if (result.success) {
      const userRef = doc(db, 'users', user.uid);
      await setDoc(
        userRef,
        {
          legacyMigratedAt: serverTimestamp(),
          legacyMigration: {
            migrated: result.migrated,
            categories: result.categories || 0,
            products: result.products || 0,
            manual: true,
          },
        },
        { merge: true }
      );
    }

    return result;
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        householdId,
        householdCode,
        householdName,
        requiresHouseholdChoice,
        loading,
        error,
        signInWithGoogleToken,
        continueWithCurrentHousehold,
        joinHouseholdByCode,
        createAdditionalHousehold,
        migrateLegacyDataNow,
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
