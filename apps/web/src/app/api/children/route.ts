import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/children — list children in the caller's family. */
export async function GET(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const db = adminDb();
  const snap = await db.collection("children").where("familyId", "==", auth.auth.familyId).get();
  const children = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return NextResponse.json({ children });
}

/** POST /api/children — create a child. */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { name, avatar, dateOfBirth } = body;
  if (!name || typeof name !== "string") {
    return NextResponse.json({ error: "Name is required." }, { status: 400 });
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const child = {
    id,
    familyId: auth.auth.familyId,
    name,
    avatar: avatar || { emoji: "👧", colorHex: "#3978A8" },
    dateOfBirth: dateOfBirth || null,
    photoData: null,
    photoUrl: null,
    activePoints: 0,
    totalPointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  };

  const db = adminDb();
  await db.collection("children").doc(id).set(child);
  return NextResponse.json({ child }, { status: 201 });
}