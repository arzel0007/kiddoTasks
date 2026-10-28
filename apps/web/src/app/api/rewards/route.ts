import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/rewards — list rewards in the caller's family. */
export async function GET(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const db = adminDb();
  const snap = await db.collection("rewards").where("familyId", "==", auth.auth.familyId).get();
  const rewards = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return NextResponse.json({ rewards });
}

/** POST /api/rewards — create a reward. */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { name, description, icon, pointCost, eligibleChildIds } = body;
  if (!name || typeof name !== "string") {
    return NextResponse.json({ error: "Name is required." }, { status: 400 });
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const reward = {
    id,
    familyId: auth.auth.familyId,
    name,
    description: description || "",
    icon: icon || "gift",
    pointCost: typeof pointCost === "number" ? pointCost : 50,
    eligibleChildIds: Array.isArray(eligibleChildIds) ? eligibleChildIds : [],
    isActive: true,
    createdBy: auth.auth.uid,
    createdAt: now,
    updatedAt: now,
    version: 1,
  };

  const db = adminDb();
  await db.collection("rewards").doc(id).set(reward);
  return NextResponse.json({ reward }, { status: 201 });
}