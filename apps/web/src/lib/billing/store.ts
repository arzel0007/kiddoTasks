/** Firestore billing records (Admin SDK only). */
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { adminDb } from "./firebase-admin";

export type SubscriptionDoc = {
  familyId: string;
  parentUid: string;
  provider: "paymongo";
  providerCustomerId: string;
  providerSubscriptionId: string;
  checkoutSessionId?: string | null;
  planId: string;
  planName: string;
  amount: number;
  currency: string;
  status: string;
  currentPeriodStart?: string | null;
  currentPeriodEnd?: string | null;
  cancelAtPeriodEnd?: boolean;
  canceledAt?: string | null;
  createdAt?: FirebaseFirestore.FieldValue;
  updatedAt?: FirebaseFirestore.FieldValue;
};

export type PaymentDoc = {
  subscriptionId: string;
  familyId: string;
  parentUid: string;
  provider: "paymongo";
  providerPaymentId: string;
  providerInvoiceId?: string | null;
  providerCheckoutSessionId?: string | null;
  amount: number;
  currency: string;
  status: string;
  paidAt?: string | null;
  createdAt?: FirebaseFirestore.FieldValue;
};

function db(): Firestore {
  return adminDb();
}

export async function getPayMongoCustomer(parentUid: string) {
  const snap = await db().doc(`paymongoCustomers/${parentUid}`).get();
  return snap.exists ? (snap.data() as { customerId: string }) : null;
}

export async function savePayMongoCustomer(
  parentUid: string,
  customerId: string,
  familyId: string,
  email: string
) {
  await db().doc(`paymongoCustomers/${parentUid}`).set(
    {
      customerId,
      familyId,
      email,
      provider: "paymongo",
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export async function getOrCreatePlanId(
  planKey: string,
  createFn: () => Promise<string>
): Promise<string> {
  const ref = db().doc(`billingPlans/${planKey}`);
  const snap = await ref.get();
  if (snap.exists) {
    const id = snap.data()?.paymongoPlanId as string | undefined;
    if (id) return id;
  }
  const id = await createFn();
  await ref.set(
    {
      paymongoPlanId: id,
      planKey,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return id;
}

export async function upsertSubscription(doc: SubscriptionDoc) {
  const ref = db().doc(`subscriptions/${doc.providerSubscriptionId}`);
  await ref.set(
    { ...doc, updatedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  return ref.id;
}

export async function getSubscriptionByPayMongoId(id: string) {
  const snap = await db().doc(`subscriptions/${id}`).get();
  return snap.exists ? ({ id: snap.id, ...snap.data() } as SubscriptionDoc & { id: string }) : null;
}

export async function getActiveSubscriptionForFamily(familyId: string) {
  const snap = await db()
    .collection("subscriptions")
    .where("familyId", "==", familyId)
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (snap.empty) return null;
  const d = snap.docs[0];
  return { id: d.id, ...(d.data() as SubscriptionDoc) };
}

export async function getSubscriptionByCheckoutSession(sessionId: string) {
  const snap = await db()
    .collection("subscriptions")
    .where("checkoutSessionId", "==", sessionId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  const d = snap.docs[0];
  return { id: d.id, ...(d.data() as SubscriptionDoc) };
}

export async function recordPayment(doc: PaymentDoc) {
  const key = doc.providerPaymentId || `unknown-${Date.now()}`;
  const ref = db().doc(`paymentTransactions/${key}`);
  const existing = await ref.get();
  if (existing.exists) return false; // idempotent
  await ref.set({ ...doc, createdAt: FieldValue.serverTimestamp() });
  return true;
}

/** Returns true if this event id was newly claimed (not a duplicate). */
export async function claimWebhookEvent(
  eventId: string,
  eventType: string
): Promise<boolean> {
  const ref = db().doc(`webhookEvents/${eventId}`);
  try {
    await ref.create({
      provider: "paymongo",
      providerEventId: eventId,
      eventType,
      processed: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  } catch {
    return false;
  }
}

export async function markWebhookProcessed(eventId: string, ok: boolean) {
  await db().doc(`webhookEvents/${eventId}`).set(
    {
      processed: ok,
      processedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/** Activate Premium on the family document (source of truth for client plan). */
export async function setFamilyPlan(familyId: string, plan: string) {
  await db().doc(`families/${familyId}`).set(
    {
      settings: { plan },
      updatedAt: FieldValue.serverTimestamp(),
      serverUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/** Server-side Premium check (webhook-driven, not client-trusted). */
export async function hasActivePremiumSubscription(
  familyId: string,
  parentEmail?: string | null
): Promise<boolean> {
  if (parentEmail) {
    const { isOwnerEmail } = await import("@/lib/entitlements");
    if (isOwnerEmail(parentEmail)) return true;
  }
  const sub = await getActiveSubscriptionForFamily(familyId);
  if (!sub) return false;
  if (sub.currentPeriodEnd) {
    const end = Date.parse(sub.currentPeriodEnd);
    if (!Number.isNaN(end) && end < Date.now()) return false;
  }
  return true;
}
