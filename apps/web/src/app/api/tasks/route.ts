import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/tasks — list tasks in the caller's family. */
export async function GET(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const db = adminDb();
  const snap = await db.collection("tasks").where("familyId", "==", auth.auth.familyId).get();
  const tasks = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  return NextResponse.json({ tasks });
}

/** POST /api/tasks — create a task. */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { name, description, icon, category, pointValue, requiresApproval, approvalBehavior, assignedChildIds, recurrence } = body;
  if (!name || typeof name !== "string") {
    return NextResponse.json({ error: "Name is required." }, { status: 400 });
  }

  const id = uuidv4();
  const now = new Date().toISOString();
  const task = {
    id,
    familyId: auth.auth.familyId,
    name,
    description: description || "",
    icon: icon || "checkmark.circle",
    category: category || "household",
    pointValue: typeof pointValue === "number" ? pointValue : 10,
    requiresApproval: requiresApproval !== false,
    approvalBehavior: approvalBehavior || "useFamilyDefault",
    assignedChildIds: Array.isArray(assignedChildIds) ? assignedChildIds : [],
    recurrence: recurrence || { type: "oneTime" },
    isActive: true,
    createdBy: auth.auth.uid,
    createdAt: now,
    updatedAt: now,
    version: 1,
  };

  const db = adminDb();
  await db.collection("tasks").doc(id).set(task);
  return NextResponse.json({ task }, { status: 201 });
}