import * as admin from "firebase-admin";

/**
 * Shared Firebase Admin bootstrap.
 * Must run before any `admin.firestore()` call — Cloud Functions CLI loads
 * modules in import order, so a top-level firestore() in a child module
 * can execute before `initializeApp()` if it isn't centralized here.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export { admin };
