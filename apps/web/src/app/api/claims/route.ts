import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/claims — submit a reward claim. */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { rewardId, childId, notes } = body;
  if (!rewardId || !childId) {
    return NextResponse.json({ error: "rewardId and childId are required." }, { status: 400 });
  }

  const db = adminDb();

  const rewardSnap = await db.collection("rewards").doc(rewardId).get();
  if (!rewardSnap.exists) {
    return NextResponse.json({ error: "Reward not found." }, { status: 404 });
  }
  const reward = rewardSnap.data()!;
  const deny = requireFamilyMatch(auth.auth, reward.familyId ?? null);
  if (deny) return deny;
  if (!reward.isActive) {
    return NextResponse.json({ error: "Reward is not active." }, { status: 400 });
  }

  const childSnap = await db.collection("children").doc(childId).get();
  if (!childSnap.exists) {
    return NextResponse.json({ error: "Child not found." }, { status: 404 });
  }
  const child = childSnap.data()!;
  const deny2 = requireFamilyMatch(auth.auth, child.familyId ?? null);
  if (deny2) return deny2;
  const eligible = reward.eligibleChildIds && reward.eligibleChildIds.length > 0
    ? reward.eligibleChildIds.includes(childId)
    : true;
  if (!eligible) {
    return NextResponse.json({ error: "Child is not eligible for this reward." }, { status: 400 });
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const claim = {
    id,
    familyId: auth.auth.familyId,
    rewardId,
    childId,
    status: "CLAIMED",
    claimedAt: now,
    notes: notes || null,
    approvedAt: null,
    approvedBy: null,
    pointDeductionTransactionId: null,
  };

  await db.collection("rewardClaims").doc(id).set(claim);
  return NextResponse.json({ claim }, { status: 201 });
}