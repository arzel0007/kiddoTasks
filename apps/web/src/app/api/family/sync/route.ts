import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/family/sync — batch push of the full family snapshot (mobile clients).
 * Writes via Firebase Admin SDK so server-side business logic is enforced.
 */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { family, removals } = body;
  if (!family || typeof family !== "object") {
    return NextResponse.json({ error: "family is required." }, { status: 400 });
  }
  const deny = requireFamilyMatch(auth.auth, family.familyId ?? family.id ?? null);
  if (deny) return deny;

  const db = adminDb();
  const batch = db.batch();
  const now = new Date().toISOString();

  // Upsert family
  const familyRef = db.collection("families").doc(family.id || family.familyId);
  batch.set(familyRef, {
    ...family,
    id: family.id || family.familyId,
    updatedAt: now,
  }, { merge: true });

  // Children
  for (const child of (family.children ?? [])) {
    const ref = db.collection("children").doc(child.id);
    batch.set(ref, { ...child, id: child.id, updatedAt: now }, { merge: true });
  }
  // Tasks
  for (const task of (family.tasks ?? [])) {
    const ref = db.collection("tasks").doc(task.id);
    batch.set(ref, { ...task, id: task.id, updatedAt: now }, { merge: true });
  }
  // Completions
  for (const c of (family.completions ?? [])) {
    const ref = db.collection("taskCompletions").doc(c.id);
    batch.set(ref, { ...c, id: c.id, updatedAt: now }, { merge: true });
  }
  // Rewards
  for (const r of (family.rewards ?? [])) {
    const ref = db.collection("rewards").doc(r.id);
    batch.set(ref, { ...r, id: r.id, updatedAt: now }, { merge: true });
  }
  // Claims
  for (const c of (family.claims ?? [])) {
    const ref = db.collection("rewardClaims").doc(c.id);
    batch.set(ref, { ...c, id: c.id, updatedAt: now }, { merge: true });
  }
  // Transactions
  for (const t of (family.transactions ?? [])) {
    const ref = db.collection("pointTransactions").doc(t.id);
    batch.set(ref, { ...t, id: t.id, updatedAt: now }, { merge: true });
  }
  // Achievements
  for (const a of (family.achievements ?? [])) {
    const ref = db.collection("achievements").doc(a.id);
    batch.set(ref, { ...a, id: a.id, updatedAt: now }, { merge: true });
  }
  // Wishlist
  for (const w of (family.wishlistItems ?? [])) {
    const ref = db.collection("wishlistItems").doc(w.id);
    batch.set(ref, { ...w, id: w.id, updatedAt: now }, { merge: true });
  }

  // Tombstone removals
  for (const id of (removals?.children ?? [])) {
    batch.delete(db.collection("children").doc(id));
  }
  for (const id of (removals?.tasks ?? [])) {
    batch.delete(db.collection("tasks").doc(id));
  }
  for (const id of (removals?.completions ?? [])) {
    batch.delete(db.collection("taskCompletions").doc(id));
  }
  for (const id of (removals?.rewards ?? [])) {
    batch.delete(db.collection("rewards").doc(id));
  }
  for (const id of (removals?.claims ?? [])) {
    batch.delete(db.collection("rewardClaims").doc(id));
  }
  for (const id of (removals?.transactions ?? [])) {
    batch.delete(db.collection("pointTransactions").doc(id));
  }
  for (const id of (removals?.achievements ?? [])) {
    batch.delete(db.collection("achievements").doc(id));
  }
  for (const id of (removals?.wishlistItems ?? [])) {
    batch.delete(db.collection("wishlistItems").doc(id));
  }

  await batch.commit();

  return NextResponse.json({ ok: true, deleted: { ...removals } });
}