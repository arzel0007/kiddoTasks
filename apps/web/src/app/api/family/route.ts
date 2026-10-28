import { NextRequest, NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import type { FamilySettings } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/family — return the family doc for the caller's family. */
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req);
  if (!auth.ok) return auth.response;

  const db = adminDb();
  const snap = await db.collection("families").doc(auth.auth.familyId).get();
  if (!snap.exists) {
    return NextResponse.json({ error: "Family not found." }, { status: 404 });
  }
  return NextResponse.json({ id: snap.id, ...snap.data() });
}

/** PUT /api/family — update family settings. */
export async function PUT(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const settings = body.settings as Partial<FamilySettings> | undefined;
  const updates: Record<string, unknown> = {};
  if (typeof body.name === "string") updates.name = body.name;
  if (typeof body.familyCode === "string") updates.familyCode = body.familyCode;
  if (settings) updates.settings = settings;
  updates.updatedAt = new Date().toISOString();

  if (Object.keys(updates).length <= 1) {
    return NextResponse.json({ error: "Nothing to update." }, { status: 400 });
  }

  const db = adminDb();
  await db.collection("families").doc(auth.auth.familyId).update(updates);
  return NextResponse.json({ ok: true });
}