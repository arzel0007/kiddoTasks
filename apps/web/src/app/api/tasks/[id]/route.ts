import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** PUT /api/tasks/:id — update a task. */
export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const doc = await db.collection("tasks").doc(id).get();
  if (!doc.exists) {
    return NextResponse.json({ error: "Task not found." }, { status: 404 });
  }
  const deny = requireFamilyMatch(auth.auth, doc.data()?.familyId ?? null);
  if (deny) return deny;

  const body = await req.json().catch(() => ({}));
  const updates: Record<string, unknown> = {};
  const allowed = ["name", "description", "icon", "category", "pointValue", "requiresApproval", "approvalBehavior", "assignedChildIds", "recurrence", "isActive"];
  for (const k of allowed) {
    if (body[k] !== undefined) updates[k] = body[k];
  }
  const docData = doc.data();
  updates.updatedAt = new Date().toISOString();
  updates.version = typeof docData?.version === "number" ? docData.version + 1 : 2;

  await db.collection("tasks").doc(id).update(updates);
  return NextResponse.json({ ok: true });
}

/** DELETE /api/tasks/:id — archive (soft delete) a task. */
export async function DELETE(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const { id } = await params;
  const db = adminDb();
  const doc = await db.collection("tasks").doc(id).get();
  if (!doc.exists) {
    return NextResponse.json({ error: "Task not found." }, { status: 404 });
  }
  const deny = requireFamilyMatch(auth.auth, doc.data()?.familyId ?? null);
  if (deny) return deny;

  await db.collection("tasks").doc(id).update({ isActive: false, updatedAt: new Date().toISOString() });
  return NextResponse.json({ ok: true });
}