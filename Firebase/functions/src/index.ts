import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/** Create family + parent docs after Auth signup. Client cannot write these collections. */
export const bootstrapFamily = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }

  const familyName = String(data.familyName || "Our family");
  const displayName = String(data.displayName || "Parent");
  const email = String(data.email || context.auth.token.email || "");
  const uid = context.auth.uid;

  const existing = await db.collection("parents").doc(uid).get();
  if (existing.exists) {
    return { familyId: existing.data()?.familyId, parentId: uid };
  }

  const familyRef = db.collection("families").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const kidsStationPIN = generateKidsPIN();
  const familyCode = generateFamilyCode();

  await db.runTransaction(async (tx) => {
    tx.set(familyRef, {
      name: familyName,
      members: [uid],
      familyCode,
      settings: {
        pointDisplaySymbol: "⭐",
        enableNotifications: true,
        celebrationAnimationsEnabled: true,
        requireApprovalByDefault: true,
        weekStartsOn: 1,
        kidsStationPIN,
      },
      createdAt: now,
      updatedAt: now,
      serverUpdatedAt: now,
    });
    tx.set(db.collection("parents").doc(uid), {
      email,
      displayName,
      familyId: familyRef.id,
      role: "owner",
      createdAt: now,
      lastSignInAt: now,
    });
    // Index for co-parent join-by-code lookups.
    tx.set(db.collection("familyCodes").doc(familyCode), {
      familyId: familyRef.id,
      createdAt: now,
    });
  });

  return { familyId: familyRef.id, parentId: uid, kidsStationPIN, familyCode };
});

/**
 * Co-parent join: authenticates a second parent and attaches them to an
 * existing family identified by the shared family code. The caller must have
 * their own Firebase Auth account (created client-side before this call).
 */
export const joinFamilyWithCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const uid = context.auth.uid;
  const familyCode = String(data?.familyCode || "").trim().toUpperCase();
  if (!familyCode) {
    throw new functions.https.HttpsError("invalid-argument", "familyCode is required");
  }

  const codeDoc = await db.collection("familyCodes").doc(familyCode).get();
  if (!codeDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Family code not found");
  }
  const familyId = codeDoc.data()?.familyId;
  if (!familyId || typeof familyId !== "string") {
    throw new functions.https.HttpsError("not-found", "Family not found for code");
  }

  const familyDoc = await db.collection("families").doc(familyId).get();
  if (!familyDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }

  const existingParent = await db.collection("parents").doc(uid).get();
  if (existingParent.exists && existingParent.data()?.familyId === familyId) {
    return { familyId, parentId: uid, alreadyMember: true };
  }
  if (existingParent.exists) {
    throw new functions.https.HttpsError("already-exists", "Account already belongs to another family");
  }

  const email = String(context.auth.token.email || "");
  const displayName = String(data?.displayName || "Parent");
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (tx) => {
    tx.set(db.collection("parents").doc(uid), {
      email,
      displayName,
      familyId,
      role: "parent",
      createdAt: now,
      lastSignInAt: now,
    });
    tx.update(db.collection("families").doc(familyId), {
      members: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: now,
      serverUpdatedAt: now,
    });
  });

  return { familyId, parentId: uid, alreadyMember: false };
});

export const createChildProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "Not a parent");
  }
  const familyId = parentDoc.data()?.familyId;
  const childRef = db.collection("children").doc();
  await childRef.set({
    name: String(data.name || "Kid"),
    familyId,
    avatar: data.avatar || { emoji: "👧", colorHex: "#EC4899" },
    dateOfBirth: data.dateOfBirth || null,
    activePoints: 0,
    totalPointsEarned: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("families").doc(familyId).update({
    members: admin.firestore.FieldValue.arrayUnion(childRef.id),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { childId: childRef.id };
});

export const submitTaskCompletion = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const { taskId, childId, familyId } = data;
  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Not authorized");
  }
  const taskDoc = await db.collection("tasks").doc(taskId).get();
  if (!taskDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Task not found");
  }
  const requiresApproval = taskDoc.data()?.requiresApproval !== false;
  const completionRef = db.collection("taskCompletions").doc();
  await completionRef.set({
    familyId,
    taskId,
    childId,
    status: requiresApproval ? "AWAITING_APPROVAL" : "COMPLETED",
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { completionId: completionRef.id, status: requiresApproval ? "AWAITING_APPROVAL" : "COMPLETED" };
});

export const claimReward = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const { rewardId, childId, familyId } = data;
  if (!rewardId || !childId || !familyId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }
  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Not authorized");
  }
  // Security: child and reward must belong to the caller's family.
  const childDoc = await db.collection("children").doc(String(childId)).get();
  if (!childDoc.exists || childDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Child not in family");
  }
  const rewardDoc = await db.collection("rewards").doc(String(rewardId)).get();
  if (!rewardDoc.exists || rewardDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Reward not in family");
  }
  const claimRef = db.collection("rewardClaims").doc();
  await claimRef.set({
    familyId,
    rewardId,
    childId,
    status: "CLAIMED",
    claimedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { claimId: claimRef.id };
});

export const rejectRewardClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const { claimId, familyId, reason } = data;
  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Not authorized");
  }
  const claimDoc = await db.collection("rewardClaims").doc(String(claimId || "")).get();
  if (!claimDoc.exists || claimDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Claim not in family");
  }
  if (claimDoc.data()?.status === "APPROVED") {
    throw new functions.https.HttpsError("already-exists", "Claim already approved");
  }
  await db.collection("rewardClaims").doc(claimId).update({
    status: "REJECTED",
    notes: reason || "",
  });
  return { success: true };
});

// MARK: - Task Approval & Points

/**
 * Approve a task completion and award points
 * This is a trusted operation - can only be called by parent
 */
export const approveTaskCompletion = functions.https.onCall(
  async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in"
      );
    }

    const { completionId, taskId, childId, familyId, pointValue } = data;

    // Validate inputs
    if (!completionId || !taskId || !childId || !familyId || !pointValue) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields"
      );
    }

    try {
      // Verify parent owns this family
      const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
      if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Not authorized to approve tasks in this family"
        );
      }

      // Verify child belongs to family
      const childDoc = await db.collection("children").doc(childId).get();
      if (!childDoc.exists || childDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Child not in family"
        );
      }

      // Verify completion exists and is not already processed
      const completionDoc = await db
        .collection("taskCompletions")
        .doc(completionId)
        .get();
      if (!completionDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Completion not found");
      }

      const completion = completionDoc.data();
      if (completion?.status === "APPROVED") {
        throw new functions.https.HttpsError(
          "already-exists",
          "Task already approved"
        );
      }

      // Security: the completion must belong to the caller's family.
      if (
        typeof completion?.familyId === "string" &&
        completion.familyId !== familyId
      ) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Completion not in family"
        );
      }

      // Security: prefer the task's server-stored point value over the
      // client-supplied one so points can't be arbitrarily awarded.
      let awardedPoints = Number(pointValue) || 0;
      const taskDoc = await db.collection("tasks").doc(String(taskId)).get();
      if (taskDoc.exists) {
        const task = taskDoc.data();
        if (typeof task?.familyId === "string" && task.familyId !== familyId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Task not in family"
          );
        }
        if (typeof task?.pointValue === "number") {
          awardedPoints = task.pointValue;
        }
      }
      if (!awardedPoints || awardedPoints <= 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid point value"
        );
      }

      // In a transaction, update completion and create point transaction
      const batch = db.batch();

      // Create point transaction
      const transactionId = db.collection("pointTransactions").doc().id;
      batch.set(db.collection("pointTransactions").doc(transactionId), {
        familyId,
        childId,
        amount: awardedPoints,
        type: "TASK_COMPLETION",
        relatedId: completionId,
        description: `Task completed: ${data.taskName || ""}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        isReversed: false,
      });

      // Update completion status
      batch.update(db.collection("taskCompletions").doc(completionId), {
        status: "APPROVED",
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: context.auth.uid,
        pointsAwarded: awardedPoints,
        pointTransactionId: transactionId,
      });

      // Update child points
      batch.update(db.collection("children").doc(childId), {
        activePoints: admin.firestore.FieldValue.increment(awardedPoints),
        totalPointsEarned: admin.firestore.FieldValue.increment(awardedPoints),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        success: true,
        transactionId,
        message: "Task approved and points awarded",
      };
    } catch (error: any) {
      console.error("Error approving task:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Error approving task: " + error.message
      );
    }
  }
);

/**
 * Reject a task completion
 */
export const rejectTaskCompletion = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in"
      );
    }

    const { completionId, familyId, reason } = data;

    try {
      // Verify parent owns this family
      const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
      if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Not authorized"
        );
      }

      // Security: the completion must belong to the caller's family and must
      // not already be approved.
      const completionDoc = await db
        .collection("taskCompletions")
        .doc(String(completionId || ""))
        .get();
      if (!completionDoc.exists || completionDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError("permission-denied", "Completion not in family");
      }
      if (completionDoc.data()?.status === "APPROVED") {
        throw new functions.https.HttpsError(
          "already-exists",
          "Completion already approved"
        );
      }

      // Update completion status
      await db.collection("taskCompletions").doc(completionId).update({
        status: "REJECTED",
        notes: reason || "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: "Task rejected",
      };
    } catch (error: any) {
      console.error("Error rejecting task:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// MARK: - Reward Approval & Point Deduction

/**
 * Approve a reward claim and deduct points
 */
export const approveRewardClaim = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in"
      );
    }

    const { claimId, rewardId, childId, familyId, pointCost } = data;

    try {
      // Verify parent owns this family
      const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
      if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Not authorized"
        );
      }

      // Get child to verify points
      const childDoc = await db.collection("children").doc(childId).get();
      if (!childDoc.exists || childDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError("permission-denied", "Invalid child");
      }

      // Security: the claim must belong to the caller's family and must not
      // already be approved (prevents double point deductions).
      const claimDoc = await db
        .collection("rewardClaims")
        .doc(String(claimId || ""))
        .get();
      if (!claimDoc.exists || claimDoc.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError("permission-denied", "Claim not in family");
      }
      if (claimDoc.data()?.status === "APPROVED") {
        throw new functions.https.HttpsError(
          "already-exists",
          "Reward claim already approved"
        );
      }

      // Security: prefer the reward's server-stored cost over the
      // client-supplied one so arbitrary amounts can't be deducted.
      let deductionCost = Number(pointCost) || 0;
      const rewardDoc = await db
        .collection("rewards")
        .doc(String(rewardId || ""))
        .get();
      if (rewardDoc.exists) {
        const reward = rewardDoc.data();
        if (typeof reward?.familyId === "string" && reward.familyId !== familyId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "Reward not in family"
          );
        }
        if (typeof reward?.pointCost === "number") {
          deductionCost = reward.pointCost;
        }
      }
      if (!deductionCost || deductionCost <= 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Invalid point cost"
        );
      }

      const childData = childDoc.data();
      if ((childData?.activePoints ?? 0) < deductionCost) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Insufficient points"
        );
      }

      // In a transaction, update claim and create point transaction
      const batch = db.batch();

      // Create point deduction transaction
      const deductionTransactionId = db.collection("pointTransactions").doc().id;
      batch.set(db.collection("pointTransactions").doc(deductionTransactionId), {
        familyId,
        childId,
        amount: -deductionCost,
        type: "REWARD_REDEMPTION",
        relatedId: claimId,
        description: `Reward claimed: ${data.rewardName || ""}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        isReversed: false,
      });

      // Update reward claim
      batch.update(db.collection("rewardClaims").doc(claimId), {
        status: "APPROVED",
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: context.auth.uid,
        pointDeductionTransactionId: deductionTransactionId,
      });

      // Deduct points from child
      batch.update(db.collection("children").doc(childId), {
        activePoints: admin.firestore.FieldValue.increment(-deductionCost),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        success: true,
        transactionId: deductionTransactionId,
        message: "Reward approved",
      };
    } catch (error: any) {
      console.error("Error approving reward:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// MARK: - Snapshot sync (cross-device)

/**
 * Merges the full family snapshot sent by the parent app.
 *
 * The iOS app pushes its local state after every mutation so families stay in
 * sync across all devices (parent phones + the shared kids iPad). This runs
 * with admin privileges, which is how the app can reconcile the point ledger
 * even though Firestore rules keep raw client ledger writes blocked.
 */
export const pushFamilySnapshot = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const uid = context.auth.uid;
  const familyId = String(data?.familyId || "");

  if (!familyId) {
    throw new functions.https.HttpsError("invalid-argument", "familyId is required");
  }

  const parentDoc = await db.collection("parents").doc(uid).get();
  if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Not authorized for this family");
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const deleted: Record<string, string[]> = {
    children: [],
    tasks: [],
    completions: [],
    rewards: [],
    claims: [],
    transactions: [],
    achievements: [],
  };

  const collectionMap: Record<string, string> = {
    children: "children",
    tasks: "tasks",
    completions: "taskCompletions",
    rewards: "rewards",
    claims: "rewardClaims",
    transactions: "pointTransactions",
    achievements: "achievements",
  };

  // Delete tombstoned docs (family-scoped). Chunk commits under the 500-op limit.
  let batch = db.batch();
  let batchCount = 0;
  const flushBatch = async () => {
    if (batchCount > 0) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  };

  for (const [key, collection] of Object.entries(collectionMap)) {
    const ids = data?.[`removed${key.charAt(0).toUpperCase()}${key.slice(1)}`]
      ?? (key === "children" ? data?.removedChildren : undefined)
      ?? [];
    const idList: string[] = Array.isArray(ids) ? ids.map(String) : [];
    for (const id of idList) {
      if (!id) continue;
      const ref = db.collection(collection).doc(id);
      const existing = await ref.get();
      if (existing.exists && existing.data()?.familyId === familyId) {
        batch.delete(ref);
        batchCount += 1;
        deleted[key].push(id);
        if (batchCount >= 400) {
          await flushBatch();
        }
      }
    }
  }

  const upsert = async (collection: string, items: any[]) => {
    for (const item of items || []) {
      if (!item || typeof item.id !== "string") continue;
      if (typeof item.familyId === "string" && item.familyId !== familyId) continue;
      batch.set(
        db.collection(collection).doc(item.id),
        toFirestoreValue({ ...item, familyId }),
        { merge: true }
      );
      batchCount += 1;
      if (batchCount >= 400) {
        await flushBatch();
      }
    }
  };

  if (data?.family && typeof data.family.id === "string") {
    const familyPayload = toFirestoreValue(data.family);
    batch.set(
      db.collection("families").doc(familyId),
      { ...familyPayload, updatedAt: now, serverUpdatedAt: now },
      { merge: true }
    );
    batchCount += 1;

    // Keep familyCode index in sync for co-parent join.
    const code = typeof data.family.familyCode === "string"
      ? String(data.family.familyCode).trim().toUpperCase()
      : "";
    if (code) {
      batch.set(
        db.collection("familyCodes").doc(code),
        { familyId, updatedAt: now },
        { merge: true }
      );
      batchCount += 1;
    }
  }

  await upsert("children", data?.children);
  await upsert("tasks", data?.tasks);
  await upsert("taskCompletions", data?.completions);
  await upsert("rewards", data?.rewards);
  await upsert("rewardClaims", data?.claims);
  await upsert("pointTransactions", data?.transactions);
  await upsert("achievements", data?.achievements);

  await flushBatch();
  return { ok: true, familyId, deleted };
});

/**
 * Deletes every Firestore document belonging to the caller's family. Used by the
 * "Reset all data" flow so a subsequent sign-in on any device does not pull the
 * old data back. Deletes the family doc and parent doc last so authorization can
 * still be checked against them for as long as possible.
 */
export const deleteFamilyData = functions.https.onCall(async (_data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const uid = context.auth.uid;
  const parentDoc = await db.collection("parents").doc(uid).get();
  if (!parentDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Parent not found");
  }
  const familyId = parentDoc.data()?.familyId;
  if (!familyId || typeof familyId !== "string") {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }

  const collections = [
    "children",
    "tasks",
    "taskCompletions",
    "rewards",
    "rewardClaims",
    "pointTransactions",
    "achievements",
  ];

  for (const collection of collections) {
    const snapshot = await db.collection(collection)
      .where("familyId", "==", familyId)
      .get();
    if (snapshot.empty) continue;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  await db.collection("families").doc(familyId).delete();
  await db.collection("parents").doc(uid).delete();

  return { ok: true };
});

/**
 * Recursively converts a JSON callable payload into Firestore-safe values,
 * turning ISO-8601 date strings into real dates so Firestore stores timestamps.
 */
function toFirestoreValue(value: unknown): any {
  if (Array.isArray(value)) {
    return value.map(toFirestoreValue);
  }
  if (value && typeof value === "object") {
    const result: Record<string, any> = {};
    for (const [key, val] of Object.entries(value)) {
      result[key] = toFirestoreValue(val);
    }
    return result;
  }
  if (typeof value === "string" && isIsoDate(value)) {
    const date = new Date(value);
    return isNaN(date.getTime()) ? value : date;
  }
  return value;
}

function isIsoDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/.test(value);
}

// MARK: - Scheduled Tasks

/**
 * Generate recurring task instances (daily)
 * Runs every day to create new task instances for recurring tasks
 */
export const generateRecurringTasks = functions.pubsub
  .schedule("every day 00:00")
  .timeZone("America/New_York")
  .onRun(async () => {
    console.log("Generating recurring task instances...");

    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Get all active recurring tasks
      const tasksSnapshot = await db
        .collection("tasks")
        .where("isActive", "==", true)
        .where("recurrence.type", "in", ["daily", "weekdays", "weekly"])
        .get();

      let createdCount = 0;

      for (const taskDoc of tasksSnapshot.docs) {
        const task = taskDoc.data();

        // Determine if task should be created for today
        let shouldCreate = false;

        switch (task.recurrence?.type) {
          case "daily":
            shouldCreate = true;
            break;
          case "weekdays":
            const dayOfWeek = today.getDay();
            shouldCreate = dayOfWeek !== 0 && dayOfWeek !== 6; // Not weekend
            break;
          case "weekly":
            // TODO: Implement day-of-week checking
            shouldCreate = true;
            break;
        }

        if (shouldCreate && task.assignedChildIds && task.assignedChildIds.length > 0) {
          // Create task instance for each child
          for (const childId of task.assignedChildIds) {
            const instanceId = `${task.id}_${today.toISOString().split("T")[0]}`;
            await db.collection("taskInstances").doc(instanceId).set({
              taskId: task.id,
              familyId: task.familyId,
              childId,
              dueDate: today,
              isCompleted: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            createdCount++;
          }
        }
      }

      console.log(`Created ${createdCount} task instances`);
      return null;
    } catch (error) {
      console.error("Error generating recurring tasks:", error);
      return null;
    }
  });

// MARK: - Utilities

/**
 * Generate a random 6-digit Kids Station PIN.
 */
function generateKidsPIN(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/** Human-friendly co-parent join code, e.g. KDO-4F7X. */
function generateFamilyCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let suffix = "";
  for (let i = 0; i < 4; i++) {
    suffix += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  }
  return `KDO-${suffix}`;
}

/**
 * Validate that a user is a parent in a specific family
 */
async function validateParentInFamily(
  parentId: string,
  familyId: string
): Promise<boolean> {
  const parentDoc = await db.collection("parents").doc(parentId).get();
  return parentDoc.exists && parentDoc.data()?.familyId === familyId;
}

/**
 * Validate that a child belongs to a family
 */
async function validateChildInFamily(
  childId: string,
  familyId: string
): Promise<boolean> {
  const childDoc = await db.collection("children").doc(childId).get();
  return childDoc.exists && childDoc.data()?.familyId === familyId;
}

// KiddoTasks push notifications: Firestore triggers (taskCompletions /
// rewardClaims / pointTransactions( + the server-managed device-token registry.
export * from "./notifications";
