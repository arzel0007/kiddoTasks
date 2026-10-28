import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/completions/:id/approve — approve a completion and award points. */
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

  const taskSnap = await db.collection("tasks").doc(comp.taskId).get();
  if (!taskSnap.exists) {
    return NextResponse.json({ error: "Task not found." }, { status: 404 });
  }
  const task = taskSnap.data()!;
  const pointValue = typeof task.pointValue === "number" ? task.pointValue : 10;
  const now = new Date().toISOString();
  const txId = uuidv4();

  await db.runTransaction(async (tx) => {
    tx.update(db.collection("taskCompletions").doc(id), {
      status: "APPROVED",
      approvedAt: now,
      approvedBy: auth.auth.uid,
      pointsAwarded: pointValue,
      pointTransactionId: txId,
    });
    tx.set(db.collection("pointTransactions").doc(txId), {
      id: txId,
      familyId: auth.auth.familyId,
      childId: comp.childId,
      type: "EARNED",
      points: pointValue,
      relatedCompletionId: id,
      note: `Completed: ${task.name}`,
      createdAt: now,
      createdBy: auth.auth.uid,
    });
  });

  return NextResponse.json({ ok: true, pointsAwarded: pointValue });
}