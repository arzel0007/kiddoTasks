import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/claims/:id/approve — approve a claim and deduct points. */
export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const claimSnap = await db.collection("rewardClaims").doc(id).get();
  if (!claimSnap.exists) {
    return NextResponse.json({ error: "Claim not found." }, { status: 404 });
  }
  const claim = claimSnap.data()!;
  const deny = requireFamilyMatch(auth.auth, claim.familyId ?? null);
  if (deny) return deny;
  if (claim.status !== "CLAIMED") {
    return NextResponse.json({ error: "Claim is not pending." }, { status: 400 });
  }

  const rewardSnap = await db.collection("rewards").doc(claim.rewardId).get();
  if (!rewardSnap.exists) {
    return NextResponse.json({ error: "Reward not found." }, { status: 404 });
  }
  const reward = rewardSnap.data()!;
  const pointCost = typeof reward.pointCost === "number" ? reward.pointCost : 0;
  const now = new Date().toISOString();
  const txId = uuidv4();

  await db.runTransaction(async (tx) => {
    tx.update(db.collection("rewardClaims").doc(id), {
      status: "APPROVED",
      approvedAt: now,
      approvedBy: auth.auth.uid,
    });
    tx.set(db.collection("pointTransactions").doc(txId), {
      id: txId,
      familyId: auth.auth.familyId,
      childId: claim.childId,
      type: "DEDUCTED",
      points: -pointCost,
      relatedClaimId: id,
      note: `Redeemed: ${reward.name}`,
      createdAt: now,
      createdBy: auth.auth.uid,
    });
  });

  return NextResponse.json({ ok: true, pointCost });
}