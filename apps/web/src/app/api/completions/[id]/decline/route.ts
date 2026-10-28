import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/completions/:id/decline — decline a completion. */
export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const compSnap = await db.collection("taskCompletions").doc(id).get();
  if (!compSnap.exists) {
    return NextResponse.json({ error: "Completion not found." }, { status: 404 });
  }
  const comp = compSnap.data()!;
  const deny = requireFamilyMatch(auth.auth, comp.familyId ?? null);
  if (deny) return deny;
  if (comp.status !== "AWAITING_APPROVAL") {
    return NextResponse.json({ error: "Completion is not pending approval." }, { status: 400 });
  }

  await db.collection("taskCompletions").doc(id).update({
    status: "REJECTED",
    updatedAt: new Date().toISOString(),
  });
  return NextResponse.json({ ok: true });
}