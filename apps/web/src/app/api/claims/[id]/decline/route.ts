import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/claims/:id/decline — decline a claim. */
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

  await db.collection("rewardClaims").doc(id).update({
    status: "REJECTED",
    updatedAt: new Date().toISOString(),
  });
  return NextResponse.json({ ok: true });
}