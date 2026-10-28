import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** PUT /api/children/:id — update a child. */
export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const doc = await db.collection("children").doc(id).get();
  if (!doc.exists) {
    return NextResponse.json({ error: "Child not found." }, { status: 404 });
  }
  const deny = requireFamilyMatch(auth.auth, doc.data()?.familyId ?? null);
  if (deny) return deny;

  const body = await req.json().catch(() => ({}));
  const updates: Record<string, unknown> = {};
  const allowed = ["name", "avatar", "dateOfBirth", "photoUrl", "activePoints", "totalPointsEarned"];
  for (const k of allowed) {
    if (body[k] !== undefined) updates[k] = body[k];
  }
  updates.updatedAt = new Date().toISOString();

  await db.collection("children").doc(id).update(updates);
  return NextResponse.json({ ok: true });
}

/** DELETE /api/children/:id — delete a child. */
export async function DELETE(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const doc = await db.collection("children").doc(id).get();
  if (!doc.exists) {
    return NextResponse.json({ error: "Child not found." }, { status: 404 });
  }
  const deny = requireFamilyMatch(auth.auth, doc.data()?.familyId ?? null);
  if (deny) return deny;

  await db.collection("children").doc(id).delete();
  return NextResponse.json({ ok: true });
}