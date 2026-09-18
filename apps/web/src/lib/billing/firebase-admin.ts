/**
 * Firebase Admin for server-side ID token verification (billing routes only).
 * Uses GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON.
 */
import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

let app: App | null = null;

function ensureAdminApp(): App {
  if (getApps().length) {
    app = getApps()[0]!;
    return app;
  }
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (json) {
    const svc = JSON.parse(json) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    app = initializeApp({
      credential: cert({
        projectId: svc.project_id,
        clientEmail: svc.client_email,
        privateKey: svc.private_key.replace(/\\n/g, "\n"),
      }),
      projectId: svc.project_id,
    });
    return app;
  }
  // ADC (local gcloud / Cloud Functions default credentials)
  app = initializeApp();
  return app;
}

export function adminAuth(): Auth {
  return getAuth(ensureAdminApp());
}

export function adminDb(): Firestore {
  return getFirestore(ensureAdminApp());
}

export async function verifyIdToken(idToken: string): Promise<{
  uid: string;
  email: string | null;
}> {
  const decoded = await adminAuth().verifyIdToken(idToken);
  return { uid: decoded.uid, email: decoded.email ?? null };
}

/** Resolve parent → familyId from Firestore (parents/{uid}). */
export async function resolveFamilyId(uid: string): Promise<{
  familyId: string | null;
  email: string | null;
  displayName: string | null;
}> {
  const snap = await adminDb().doc(`parents/${uid}`).get();
  if (!snap.exists) return { familyId: null, email: null, displayName: null };
  const data = snap.data() ?? {};
  return {
    familyId: (data.familyId as string) ?? null,
    email: (data.email as string) ?? null,
    displayName: (data.displayName as string) ?? null,
  };
}
