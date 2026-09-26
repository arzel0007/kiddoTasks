"use client";

import { deleteDoc, doc, getDoc, setDoc } from "firebase/firestore";
import { firebaseAuth, firestore, isFirebaseConfigured } from "./firebase";

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; i += 1) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

/** Stable Firestore doc id from a push endpoint (hash via simple FNV-style). */
function endpointDocId(endpoint: string): string {
  let hash = 2166136261;
  for (let i = 0; i < endpoint.length; i += 1) {
    hash ^= endpoint.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return `ep_${(hash >>> 0).toString(16)}_${endpoint.length}`;
}

export function isWebPushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  );
}

async function registerServiceWorker(): Promise<ServiceWorkerRegistration> {
  return navigator.serviceWorker.register("/sw.js", { scope: "/" });
}

/** Public VAPID key from env (baked at build). */
export async function getVapidPublicKey(): Promise<string | null> {
  return process.env.NEXT_PUBLIC_WEB_PUSH_VAPID_PUBLIC_KEY || null;
}

async function resolveFamilyId(): Promise<string | null> {
  const user = firebaseAuth().currentUser;
  if (!user || !isFirebaseConfigured) return null;
  const snap = await getDoc(doc(firestore(), "parents", user.uid));
  const familyId = snap.data()?.familyId;
  return typeof familyId === "string" && familyId ? familyId : null;
}

export async function subscribeWebPush(): Promise<{ ok: boolean; error?: string }> {
  if (!isWebPushSupported()) {
    return { ok: false, error: "This browser doesn’t support push notifications." };
  }
  if (!isFirebaseConfigured) {
    return { ok: false, error: "Firebase isn’t configured." };
  }
  const user = firebaseAuth().currentUser;
  if (!user) {
    return { ok: false, error: "Sign in as a parent first." };
  }

  try {
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      return { ok: false, error: "Notifications are blocked for this site." };
    }

    const reg = await registerServiceWorker();
    await navigator.serviceWorker.ready;

    const vapidKey = await getVapidPublicKey();
    if (!vapidKey) {
      return { ok: false, error: "Push key isn’t configured yet." };
    }

    const existing = await reg.pushManager.getSubscription();
    const subscription =
      existing ??
      (await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidKey) as unknown as BufferSource,
      }));

    const json = subscription.toJSON();
    if (!json.endpoint || !json.keys?.p256dh || !json.keys?.auth) {
      return { ok: false, error: "Browser returned an incomplete subscription." };
    }

    const familyId = await resolveFamilyId();
    if (!familyId) {
      return { ok: false, error: "No family for this account." };
    }

    const id = endpointDocId(json.endpoint);
    await setDoc(
      doc(firestore(), "webPushSubscriptions", id),
      {
        familyId,
        parentUid: user.uid,
        endpoint: json.endpoint,
        keys: { p256dh: json.keys.p256dh, auth: json.keys.auth },
        userAgent: navigator.userAgent.slice(0, 200),
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    return { ok: true };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "Couldn’t enable notifications.",
    };
  }
}

export async function unsubscribeWebPush(): Promise<{ ok: boolean; error?: string }> {
  try {
    const reg = await navigator.serviceWorker.getRegistration("/");
    const subscription = await reg?.pushManager.getSubscription();
    if (subscription && isFirebaseConfigured && firebaseAuth().currentUser) {
      try {
        await deleteDoc(
          doc(firestore(), "webPushSubscriptions", endpointDocId(subscription.endpoint))
        );
      } catch {
        /* still unsubscribe locally */
      }
    }
    if (subscription) {
      await subscription.unsubscribe();
    }
    return { ok: true };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "Couldn’t turn off notifications.",
    };
  }
}

export async function webPushSubscriptionStatus(): Promise<
  "unsupported" | "granted" | "denied" | "default" | "subscribed" | "unsubscribed"
> {
  if (!isWebPushSupported()) return "unsupported";
  if (Notification.permission === "denied") return "denied";
  const reg = await navigator.serviceWorker.getRegistration("/");
  const sub = await reg?.pushManager.getSubscription();
  if (sub) return "subscribed";
  return Notification.permission === "granted" ? "granted" : "default";
}

/** Remove this browser's subscription doc if the endpoint is known (sign-out cleanup). */
export async function cleanupWebPushSubscription(): Promise<void> {
  try {
    const reg = await navigator.serviceWorker.getRegistration("/");
    const sub = await reg?.pushManager.getSubscription();
    if (sub && isFirebaseConfigured) {
      await deleteDoc(
        doc(firestore(), "webPushSubscriptions", endpointDocId(sub.endpoint))
      );
    }
  } catch {
    /* ignore */
  }
}
