import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/completions — submit a task completion. */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  const body = await req.json().catch(() => ({}));
  const { taskId, childId, notes, occurrenceKey } = body;
  if (!taskId || !childId) {
    return NextResponse.json({ error: "taskId and childId are required." }, { status: 400 });
  }

  const db = adminDb();

  // Verify task belongs to family
  const taskSnap = await db.collection("tasks").doc(taskId).get();
  if (!taskSnap.exists) {
    return NextResponse.json({ error: "Task not found." }, { status: 404 });
  }
  const task = taskSnap.data()!;
  const deny = requireFamilyMatch(auth.auth, task.familyId ?? null);
  if (deny) return deny;

  // Verify child belongs to family
  const childSnap = await db.collection("children").doc(childId).get();
  if (!childSnap.exists) {
    return NextResponse.json({ error: "Child not found." }, { status: 404 });
  }
  const child = childSnap.data()!;
  const deny2 = requireFamilyMatch(auth.auth, child.familyId ?? null);
  if (deny2) return deny2;

  // Determine if approval is required
  const settings = (await db.collection("families").doc(auth.auth.familyId).get()).data()?.settings || {};
  const requireApprovalByDefault = settings.requireApprovalByDefault !== false;
  const approvalBehavior = task.approvalBehavior || "useFamilyDefault";
  const requiresApproval =
    approvalBehavior === "alwaysRequireApproval"
      ? true
      : approvalBehavior === "autoApprove"
      ? false
      : requireApprovalByDefault;

  const id = uuidv4();
  const now = new Date().toISOString();
  const completion = {
    id,
    familyId: auth.auth.familyId,
    taskId,
    childId,
    status: requiresApproval ? "AWAITING_APPROVAL" : "APPROVED",
    completedAt: now,
    notes: notes || null,
    occurrenceKey: occurrenceKey || null,
    approvedAt: null,
    approvedBy: null,
    pointsAwarded: null,
    pointTransactionId: null,
  };

  await db.collection("taskCompletions").doc(id).set(completion);

  // Auto-approve: award points immediately
  if (!requiresApproval) {
    const pointValue = typeof task.pointValue === "number" ? task.pointValue : 10;
    const txId = uuidv4();
    await db.collection("taskCompletions").doc(id).update({
      status: "APPROVED",
      approvedAt: now,
      approvedBy: auth.auth.uid,
      pointsAwarded: pointValue,
      pointTransactionId: txId,
    });
    await db.collection("pointTransactions").doc(txId).set({
      id: txId,
      familyId: auth.auth.familyId,
      childId,
      type: "EARNED",
      points: pointValue,
      relatedCompletionId: id,
      note: `Completed: ${task.name}`,
      createdAt: now,
      createdBy: auth.auth.uid,
    });
  }

  return NextResponse.json({ completion, requiresApproval }, { status: 201 });
}