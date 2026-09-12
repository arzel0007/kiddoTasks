import { initializeApp, getApps, getApp, FirebaseApp } from "firebase/app";
import { getAuth, Auth } from "firebase/auth";
import { getFirestore, Firestore } from "firebase/firestore";
import { getStorage, FirebaseStorage } from "firebase/storage";
import { getFunctions, Functions } from "firebase/functions";

/**
 * Config comes only from NEXT_PUBLIC_FIREBASE_* env (apps/web/.env.local).
 * Never hardcode API keys in source.
 *
 * Copy .env.example → .env.local and fill from:
 * Firebase Console → Project settings → Your apps → Web → SDK setup
 */
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

export const isFirebaseConfigured = Boolean(
  firebaseConfig.apiKey && firebaseConfig.projectId
);

let app: FirebaseApp | null = null;
let initTried = false;

function ensureApp(): FirebaseApp | null {
  if (!isFirebaseConfigured) return null;
  if (typeof window === "undefined") return null;
  if (app) return app;
  if (initTried) {
    initTried = false;
  }
  initTried = true;
  try {
    app = getApps().length ? getApp() : initializeApp(firebaseConfig);
  } catch (e) {
    console.error("[Firebase] init failed", e);
    app = null;
    return null;
  }
  return app;
}

if (typeof window !== "undefined") {
  ensureApp();
}

export function firebaseApp(): FirebaseApp {
  const instance = ensureApp();
  if (!instance) {
    throw new Error(
      "Firebase is not configured. Copy apps/web/.env.example to .env.local and set NEXT_PUBLIC_FIREBASE_* keys, then restart `npm run dev`."
    );
  }
  return instance;
}

export function firebaseAuth(): Auth {
  return getAuth(firebaseApp());
}

export function firestore(): Firestore {
  return getFirestore(firebaseApp());
}

export function firebaseStorage(): FirebaseStorage {
  return getStorage(firebaseApp());
}

export function firebaseFunctions(): Functions {
  return getFunctions(firebaseApp(), "us-central1");
}
