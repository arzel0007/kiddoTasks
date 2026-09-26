/**
 * Web Push (VAPID) registry + send helper.
 * Complements APNs/FCM so parents can get notifications without a paid
 * Apple Developer account (Safari/Chrome PWA on any device).
 *
 * Clients never write `webPushSubscriptions` — auth-only callables register /
 * unregister. Sends respect `families/{id}.settings.enableNotifications`.
 */
import * as functions from "firebase-functions";
import * as webpush from "web-push";
import { admin, db } from "./firebase-init";

const VAPID_PUBLIC_KEY = process.env.WEB_PUSH_VAPID_PUBLIC_KEY || "";
const VAPID_PRIVATE_KEY = process.env.WEB_PUSH_VAPID_PRIVATE_KEY || "";
const VAPID_SUBJECT =
  process.env.WEB_PUSH_VAPID_SUBJECT || "mailto:xxarzelxx@gmail.com";

let webPushReady = false;

function ensureWebPush(): boolean {
  if (webPushReady) return true;
  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) {
    console.warn("[webpush] VAPID keys missing — set WEB_PUSH_VAPID_* in functions .env");
    return false;
  }
  try {
    webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
    webPushReady = true;
    return true;
  } catch (e) {
    console.error("[webpush] setVapidDetails failed:", e);
    return false;
  }
}

export function isWebPushConfigured(): boolean {
  return Boolean(VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY);
}

type WebPushSub = {
  familyId: string;
  parentUid: string;
  endpoint: string;
  keys: { p256dh: string; auth: string };
  userAgent?: string;
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
};

/** Stable doc id for an endpoint (endpoints can be long / contain slashes). */
function endpointDocId(endpoint: string): string {
  const crypto = require("crypto") as typeof import("crypto");
  return crypto.createHash("sha256").update(endpoint).digest("hex");
}

async function parentFamilyId(uid: string): Promise<string | null> {
  const snap = await db.collection("parents").doc(uid).get();
  const familyId = snap.exists ? snap.data()?.familyId : null;
  return typeof familyId === "string" && familyId ? familyId : null;
}

// MARK: - Client callables

/** Store a browser push subscription for the signed-in parent's family. */
export const registerWebPushSubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    }
    const familyId = await parentFamilyId(context.auth.uid);
    if (!familyId) {
      throw new functions.https.HttpsError("failed-precondition", "No family for this account");
    }

    const endpoint = String(data?.endpoint || "").trim();
    const keys = data?.keys as { p256dh?: string; auth?: string } | undefined;
    if (!endpoint || !keys?.p256dh || !keys?.auth) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid push subscription");
    }

    const docId = endpointDocId(endpoint);
    const payload: WebPushSub = {
      familyId,
      parentUid: context.auth.uid,
      endpoint,
      keys: { p256dh: String(keys.p256dh), auth: String(keys.auth) },
      userAgent: String(data?.userAgent || "").slice(0, 200),
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
    };

    const ref = db.collection("webPushSubscriptions").doc(docId);
    const existing = await ref.get();
    await ref.set(
      existing.exists ? payload : { ...payload, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
    return { ok: true, id: docId };
  }
);

/** Remove a browser push subscription (endpoint hash or raw endpoint). */
export const unregisterWebPushSubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
    }
    const endpoint = String(data?.endpoint || "").trim();
    const id = String(data?.id || "").trim() || (endpoint ? endpointDocId(endpoint) : "");
    if (!id) {
      throw new functions.https.HttpsError("invalid-argument", "Missing endpoint");
    }
    const ref = db.collection("webPushSubscriptions").doc(id);
    const snap = await ref.get();
    if (snap.exists) {
      const familyId = await parentFamilyId(context.auth.uid);
      const owner = snap.data()?.familyId;
      // Only the same family (or the registering parent) may remove.
      if (familyId && owner === familyId) {
        await ref.delete();
      }
    }
    return { ok: true };
  }
);

/** Public VAPID key for the browser `pushManager.subscribe`. */
export const getWebPushPublicKey = functions.https.onCall(async () => {
  return { publicKey: VAPID_PUBLIC_KEY || null };
});

// MARK: - Send (used by notification triggers)

/**
 * Send a Web Push to every subscription in a family.
 * Never throws — notification failures must not fail the triggering write.
 */
export async function sendWebPushToFamily(args: {
  familyId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  try {
    if (!ensureWebPush()) return;

    const familyDoc = await db.collection("families").doc(args.familyId).get();
    if (!familyDoc.exists) return;
    const settings = familyDoc.data()?.settings ?? {};
    if (settings.enableNotifications === false) return;

    const snap = await db
      .collection("webPushSubscriptions")
      .where("familyId", "==", args.familyId)
      .get();
    if (snap.empty) return;

    const payload = JSON.stringify({
      title: args.title,
      body: args.body,
      data: args.data ?? {},
      tag: args.data?.kind || "kiddotasks",
    });

    const dead: string[] = [];
    await Promise.all(
      snap.docs.map(async (doc) => {
        const sub = doc.data() as WebPushSub;
        if (!sub.endpoint || !sub.keys?.p256dh || !sub.keys?.auth) {
          dead.push(doc.id);
          return;
        }
        try {
          await webpush.sendNotification(
            {
              endpoint: sub.endpoint,
              keys: { p256dh: sub.keys.p256dh, auth: sub.keys.auth },
            },
            payload
          );
        } catch (e: unknown) {
          const status = (e as { statusCode?: number }).statusCode;
          // 404 / 410 — subscription expired or browser revoked it.
          if (status === 404 || status === 410) {
            dead.push(doc.id);
          } else {
            console.warn("[webpush] send failed:", status, (e as Error).message);
          }
        }
      })
    );

    if (dead.length > 0) {
      const batch = db.batch();
      dead.forEach((id) => batch.delete(db.collection("webPushSubscriptions").doc(id)));
      await batch.commit();
    }
  } catch (error) {
    console.error("sendWebPushToFamily failed:", error);
  }
}
