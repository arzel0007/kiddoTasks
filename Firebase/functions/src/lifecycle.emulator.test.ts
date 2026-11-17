import * as admin from "firebase-admin";
import {
  approveRewardClaim,
  approveTaskCompletion,
  claimReward,
  rejectRewardClaim,
  rejectTaskCompletion,
  submitTaskCompletion,
} from "./index";
import { computeOccurrenceKey } from "./occurrence";

const describeWithFirestoreEmulator = process.env.FIRESTORE_EMULATOR_HOST
  ? describe
  : describe.skip;
const call = (fn: any, data: Record<string, unknown>, uid: string) =>
  fn.run(data, { auth: { uid } });
const rejectedWithCode = async (promise: Promise<unknown>, code: string) => {
  await expect(promise).rejects.toMatchObject({ code });
};

describeWithFirestoreEmulator("lifecycle callable Firestore transactions", () => {
  const db = admin.firestore();
  const suffix = `${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const familyId = `emulator_family_${suffix}`;
  const parentUid = `emulator_parent_${suffix}`;
  const childId = `emulator_child_${suffix}`;
  const otherChildId = `emulator_other_child_${suffix}`;
  const taskId = `emulator_task_${suffix}`;
  const otherTaskId = `emulator_other_task_${suffix}`;
  const rewardId = `emulator_reward_${suffix}`;
  const claimId = `emulator_claim_${suffix}`;
  const refs: FirebaseFirestore.DocumentReference[] = [];

  async function seed(ref: FirebaseFirestore.DocumentReference, data: object) {
    refs.push(ref);
    await ref.set(data);
  }

  async function seedFamily() {
    await seed(db.collection("families").doc(familyId), { settings: {} });
    await seed(db.collection("parents").doc(parentUid), { familyId });
    await seed(db.collection("children").doc(childId), {
      familyId, activePoints: 100, totalPointsEarned: 0,
    });
    await seed(db.collection("children").doc(otherChildId), {
      familyId, activePoints: 100, totalPointsEarned: 0,
    });
    await seed(db.collection("tasks").doc(taskId), { familyId, name: "Task", pointValue: 7 });
    await seed(db.collection("tasks").doc(otherTaskId), { familyId, name: "Other task", pointValue: 99 });
    await seed(db.collection("rewards").doc(rewardId), { familyId, name: "Reward", pointCost: 12 });
  }

  afterEach(async () => {
    const batch = db.batch();
    for (const ref of refs.splice(0)) batch.delete(ref);
    await batch.commit();
  });

  it("creates only one open reward claim when identical requests race", async () => {
    await seedFamily();
    const results = await Promise.allSettled([
      call(claimReward, { familyId, rewardId, childId }, parentUid),
      call(claimReward, { familyId, rewardId, childId }, parentUid),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1);
    const claims = await db.collection("rewardClaims").where("familyId", "==", familyId).get();
    expect(claims.size).toBe(1);
    for (const doc of claims.docs) refs.push(doc.ref);
  });

  it("rejects task approval when supplied task or child differs from the stored completion", async () => {
    await seedFamily();
    const completionId = `completion_${suffix}`;
    await seed(db.collection("taskCompletions").doc(completionId), {
      familyId, taskId, childId, status: "AWAITING_APPROVAL", completedAt: new Date(),
    });
    await rejectedWithCode(
      call(approveTaskCompletion, { familyId, completionId, taskId: otherTaskId, childId }, parentUid),
      "invalid-argument"
    );
    await rejectedWithCode(
      call(approveTaskCompletion, { familyId, completionId, taskId, childId: otherChildId }, parentUid),
      "invalid-argument"
    );
    expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(100);
  });

  it("allows only one decision and one point award when task approval races with rejection", async () => {
    await seedFamily();
    const completionId = `completion_${suffix}`;
    const completionRef = db.collection("taskCompletions").doc(completionId);
    await seed(completionRef, {
      familyId, taskId, childId, status: "AWAITING_APPROVAL", completedAt: new Date(),
    });
    const results = await Promise.allSettled([
      call(approveTaskCompletion, { familyId, completionId, taskId, childId }, parentUid),
      call(rejectTaskCompletion, { familyId, completionId }, parentUid),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1);
    const completion = (await completionRef.get()).data();
    if (completion?.status === "APPROVED") {
      expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(107);
      const ledger = await db.collection("pointTransactions").where("relatedId", "==", completionId).get();
      expect(ledger.size).toBe(1);
      for (const doc of ledger.docs) refs.push(doc.ref);
    } else {
      expect(completion?.status).toBe("REJECTED");
      expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(100);
    }
  });

  it("rejects reward approval when the claim's reward or child does not match", async () => {
    await seedFamily();
    const ref = db.collection("rewardClaims").doc(claimId);
    await seed(ref, { familyId, rewardId, childId, status: "CLAIMED" });
    await rejectedWithCode(
      call(approveRewardClaim, { familyId, claimId, rewardId: "another_reward", childId }, parentUid),
      "invalid-argument"
    );
    await rejectedWithCode(
      call(approveRewardClaim, { familyId, claimId, rewardId, childId: otherChildId }, parentUid),
      "invalid-argument"
    );
    expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(100);
  });

  it("allows only one decision and deduction when reward approval races with rejection", async () => {
    await seedFamily();
    const claimRef = db.collection("rewardClaims").doc(claimId);
    await seed(claimRef, { familyId, rewardId, childId, status: "CLAIMED" });
    const results = await Promise.allSettled([
      call(approveRewardClaim, { familyId, claimId, rewardId, childId }, parentUid),
      call(rejectRewardClaim, { familyId, claimId }, parentUid),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    expect(results.filter((result) => result.status === "rejected")).toHaveLength(1);
    const claim = (await claimRef.get()).data();
    if (claim?.status === "APPROVED") {
      expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(88);
      const ledger = await db.collection("pointTransactions").where("relatedId", "==", claimId).get();
      expect(ledger.size).toBe(1);
      for (const doc of ledger.docs) refs.push(doc.ref);
    } else {
      expect(claim?.status).toBe("REJECTED");
      expect((await db.collection("children").doc(childId).get()).data()?.activePoints).toBe(100);
    }
  });

  it("finds a pending current occurrence after more than 50 same-occurrence records", async () => {
    await seedFamily();
    await db.collection("tasks").doc(taskId).update({
      familyId, name: "Daily task", pointValue: 7, isActive: true,
      recurrence: { type: "daily" }, approvalBehavior: "alwaysRequireApproval",
    });
    const now = new Date();
    const occurrenceKey = computeOccurrenceKey("daily", now, "Asia/Manila");
    for (let i = 0; i < 70; i += 1) {
      const ref = db.collection("taskCompletions").doc(`a_${suffix}_${String(i).padStart(3, "0")}`);
      await seed(ref, {
        familyId, taskId, childId, status: "APPROVED", occurrenceKey,
        completedAt: admin.firestore.Timestamp.fromDate(now),
      });
    }
    const blocker = db.collection("taskCompletions").doc(`z_${suffix}_pending`);
    await seed(blocker, {
      familyId, taskId, childId, status: "AWAITING_APPROVAL", occurrenceKey,
      completedAt: admin.firestore.Timestamp.fromDate(now),
    });
    await rejectedWithCode(
      call(submitTaskCompletion, {
        familyId, taskId, childId, completedAt: now.toISOString(), timezone: "Asia/Manila",
      }, parentUid),
      "already-exists"
    );
  });
});
