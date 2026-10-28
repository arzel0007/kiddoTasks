import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/transactions — list point transactions for the caller's family. */
export async function GET(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { searchParams } = new URL(req.url);
  const childId = searchParams.get("childId") || undefined;

  const db = adminDb();
  let q = db.collection("pointTransactions").where("familyId", "==", auth.auth.familyId);
  if (childId) q = q.where("childId", "==", childId);
  const snap = await q.get();
  const transactions = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return NextResponse.json({ transactions });
}