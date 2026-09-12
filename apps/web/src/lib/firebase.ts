import { initializeApp, getApps, getApp, FirebaseApp } from "firebase/app";
import { getAuth, Auth } from "firebase/auth";
import { getFirestore, Firestore } from "firebase/firestore";
import { getStorage, FirebaseStorage } from "firebase/storage";
import { getFunctions, Functions } from "firebase/functions";

/**
 * Defaults from the iOS GoogleService-Info.plist (same Firebase project).
 * NEXT_PUBLIC_* in .env.local overrides these when set.
 * Firebase web API keys are public identifiers — protection is Auth + rules.
 */
const FALLBACK_CONFIG = {
  apiKey: "AIzaSyCqcktIZBBeNy50hWvGvPNRapvnsI8w_KI",
  authDomain: "kiddotasks-app.firebaseapp.com",
  projectId: "kiddotasks-app",
  storageBucket: "kiddotasks-app.firebasestorage.app",
  messagingSenderId: "521956076622",
  // Prefer a Web app id from the console when available; iOS id still works
  // for Auth/Firestore on this project in practice.
  appId: "1:521956076622:ios:3b8724f467d7bb773f671f",
};

function resolve(
  key: keyof typeof FALLBACK_CONFIG,
  envValue: string | undefined
): string {
  const v = envValue?.trim();
  return v && v.length > 0 ? v : FALLBACK_CONFIG[key];
}

const firebaseConfig = {
  apiKey: resolve("apiKey", process.env.NEXT_PUBLIC_FIREBASE_API_KEY),
  authDomain: resolve("authDomain", process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN),
  projectId: resolve("projectId", process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID),
  storageBucket: resolve(
    "storageBucket",
    process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET
  ),
  messagingSenderId: resolve(
    "messagingSenderId",
    process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
  ),
  appId: resolve("appId", process.env.NEXT_PUBLIC_FIREBASE_APP_ID),
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
    // Retry once after a prior failure (HMR / cold start).
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
      "Firebase is not configured. Check apps/web/src/lib/firebase.ts FALLBACK_CONFIG."
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
  // Callables are deployed us-central1 on this project.
  return getFunctions(firebaseApp(), "us-central1");
}
