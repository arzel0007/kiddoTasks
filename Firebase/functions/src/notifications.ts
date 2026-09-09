/**
 * Push notification triggers + device-token registry for KiddoTasks.
 *
 * Design:
 *  - The app is local-first: every mutation is pushed up through the
 *    `pushFamilySnapshot` callable (and legacy per-action callables also write
 *    the same collections), so watching Firestore writes on `taskCompletions`,
 *    `rewardClaims` and `pointTransactions` covers ALL event paths with ONE
 *    mechanism.
 *  - Dedup: approvals / rejections notify via their status-transition triggers;
 *    their side-effect ledger writes (`TASK_COMPLETION` / `REWARD_REDEMPTION`)
 *    are skipped by the point-transaction trigger (already notified). The 5-minute
 *    recency guard kills replay storms during first-sync and re-pushes of history.

 *  - Tokens are stored server-sidein `deviceTokens/{fcmToken}` — clients never
 *    write that collection (Firestore rules deny it(; auth-only callables register /
 *    unregister. Sends respect `families/{id}.settings.enableNotifications` (the
 *    existing "Family notifications" toggle, now real.
 */
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const RECENCY_WINDOW_MS = 5 * 60 * 1000;
const SKIPPED_LEDGER_TYPES = new Set(["TASK_COMPLETION", "REWARD_REDEMPTION"]);

// MARK: - Helpers

interface MaybeTimestamp {
  toDate(): Date;
}

function isRecent(ts: MaybeTimestamp | undefined | null): boolean {
  if (!ts) return false;
  return Date.now() - ts.toDate().getTime() < RECENCY_WINDOW_MS;
}

function latest(
  first: MaybeTimestamp | undefined | null,
  ...rest: Array<MaybeTimestamp | undefined | null>
): MaybeTimestamp | undefined {
  let best = first ?? undefined;
  for (const candidate of rest) {
    if (candidate) {
      if (!best || candidate.toDate().getTime() > best.toDate().getTime()) {
        best = candidate;
      }
    }
  }
  return best;
}

/** Pulls display names/cost for a completion/claim/transaction in one round-trip. */
async function resolveNames(
  childId?: string,
  taskId?: string,
  rewardId?: string
): Promise<{
  childName?: string;
  taskName?: string;
  rewardName?: string;
  rewardCost?: number;
}> {
  const childPromise = childId ? db.collection("children").doc(childId).get() : Promise.resolve(null);
  const taskPromise = taskId ? db.collection("tasks").doc(taskId).get() : Promise.resolve(null);
  const rewardPromise = rewardId ? db.collection("rewards").doc(rewardId).get() : Promise.resolve(null);
  const [childDoc, taskDoc, rewardDoc] = await Promise.all([childPromise, taskPromise, rewardPromise]);
  const childData = childDoc ? childDoc.data() : null;
  const taskData = taskDoc ? taskDoc.data() : null;
  const rewardData = rewardDoc ? rewardDoc.data() : null;
 return {
    childName: typeof childData?.name === "string" ? childData.name : undefined,
    taskName: typeof taskData?.name === "string" ? taskData.name : undefined,
    rewardName: typeof rewardData?.name === "string" ? rewardData.name : undefined,
    rewardCost: typeof rewardData?.pointCost === "number" ? rewardData.pointCost : undefined,
  };
}

function safeString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.length > 0 ? value : fallback;
}

/** Sends a push to every registered device in a family. Never throws (the
 *  write that triggered us must not fail because notifications hiccuped. */
async function notifyFamily(args: {
  familyId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  try {
    const familyDoc = await db.collection("families").doc(args.familyId).get();
    if (!familyDoc.exists) return;
    const settings = familyDoc.data()?.settings ?? {};
    if (settings.enableNotifications === false) return;

    const tokensSnapshot = await db
      .collection("deviceTokens")
      .where("familyId", "==", args.familyId)
      .get();
    if (tokensSnapshot.empty) return;

    const tokens = tokensSnapshot.docs.map((doc) => doc.id);
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: args.title, body: args.body },
      data: args.data ?? {},
    });

    // Prune dead tokens so registries stay clean over time.

    const deadTokens: string[] = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code ?? "";
      if (
        !result.success &&
        (code.includes("registration-token-not-registered") ||
          code.includes("unregistered") ||
          code.includes("invalid-registration") ||
          code.includes("sender-id-mismatch") ||
          code.includes("mismatched-credential"))
      ) {
        const tok = tokens[index];
        if (tok) deadTokens.push(tok);
      }
    });
    if (deadTokens.length > 0) {
      const batch = db.batch();
      deadTokens.forEach((tok) => batch.delete(db.collection("deviceTokens").doc(tok)));
      await batch.commit();
    }
  } catch (error) {
    console.error("notifyFamily failed:", error);
  }
}

// ── TRIGGERS ──

/**
 * (1) Kid submits a task awaiting approval, or (3) an auto-approved task
 * completes (requiresApproval == false). Notifies the parents.
 */
export const notifyOnTaskCompletionCreated = functions.firestore
  .document("taskCompletions/{completionId}")
  .onCreate(async (snap, context) => {
    const after = snap.data();
    if (!after || !after.familyId || !after.childId || !after.taskId) return;

    if (!isRecent(latest(after.completedAt, after.createdAt))) return;

    const status = after.status ?? "";
    if (status !== "AWAITING_APPROVAL" && status !== "COMPLETED") return;

    const names = await resolveNames(after.childId, after.taskId);
    const kid = safeString(names.childName, "Your kid");
    const task = safeString(names.taskName, "a task");

    if (status === "AWAITING_APPROVAL") {
      await notifyFamily({
        familyId: after.familyId,
        title: `${kid} finished a task`,
        body: `"${task}" needs your approval`,
        data: {
          type: "taskAwaitingApproval",
          familyId: after.familyId,
          completionId: context.params.completionId,
          childId: after.childId,
          taskId: after.taskId,
        },
      });
    } else if (status === "COMPLETED") {
      const points = typeof after.pointsAwarded === "number" ? ` (+${after.pointsAwarded}⭐)` : "";
      await notifyFamily({
        familyId: after.familyId,
        title: `${kid} completed a task`,
        body: `"${task}"${points}`,
        data: {
          type: "taskCompleted",
          familyId: after.familyId,
          completionId: context.params.completionId,
          childId: after.childId,
          taskId: after.taskId,
        },
      });
    }
  });

/**
 * (4) Task approved / (5) rejected by a parent. Notifies the whole family
 * (parents + kids-station devices), so the kid sees the decision immediately
 * (with the parent's message when rejected). Deduplicated via the status
 * transition check (re-pushes of the same state do nothing(.
 */
export const notifyOnTaskCompletionUpdated = functions.firestore
  .document("taskCompletions/{completionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!after || !after.familyId || !after.childId || !after.taskId) return;

    const prevStatus = before?.status ?? "";
    const nextStatus = after.status ?? "";
    if (prevStatus === nextStatus) return;
    if (nextStatus !== "APPROVED" && nextStatus !== "REJECTED") return;
    if (prevStatus === "APPROVED" || prevStatus === "REJECTED") return;

    if (!isRecent(latest(after.approvedAt, after.completedAt, after.updatedAt, after.createdAt))) return;

    const names = await resolveNames(after.childId, after.taskId);
    const kid = safeString(names.childName, "Your kid");
    const task = safeString(names.taskName, "a task");

    if (nextStatus === "APPROVED") {
      const points = typeof after.pointsAwarded === "number" ? ` +${after.pointsAwarded}⭐` : "";
      await notifyFamily({
        familyId: after.familyId,
        title: "Task approved ✅",
        body: `${kid}: "${task}"${points}`,
        data: {
          type: "taskApproved",
          familyId: after.familyId,
          completionId: context.params.completionId,
          childId: after.childId,
          taskId: after.taskId,
        },
      });
    } else {
      await notifyFamily({
        familyId: after.familyId,
        title: "Task needs another try",
        body: `${kid}: "${task}" — ${safeString(after.notes, "Parent asked to try again")}`,
        data: {
          type: "taskRejected",
          familyId: after.familyId,
          completionId: context.params.completionId,
          childId: after.childId,
          taskId: after.taskId,
        },
      });
    }
  });

// ── TRIGGERS 2 ──

/**
 * (2) Kid requests a reward. Notifies the parents so they can approve.
 */
export const notifyOnRewardClaimCreated = functions.firestore
  .document("rewardClaims/{claimId}")
  .onCreate(async (snap, context) => {
    const after = snap.data();
    if (!after || !after.familyId || !after.childId || !after.rewardId) return;

    if (!after.status || after.status !== "CLAIMED") return;
    if (!isRecent(latest(after.claimedAt, after.createdAt))) return;

    const names = await resolveNames(after.childId, undefined, after.rewardId);
    const kid = safeString(names.childName, "Your kid");
    const reward = safeString(names.rewardName, "a reward");
    const cost = typeof names.rewardCost === "number" ? ` (${names.rewardCost}⭐)` : "";

    await notifyFamily({
      familyId: after.familyId,
      title: `${kid} wants a reward`,
      body: `"${reward}"${cost} — awaiting your approval`,
      data: {
        type: "rewardClaimed",
        familyId: after.familyId,
        claimId: context.params.claimId,
        childId: after.childId,
        rewardId: after.rewardId,
      },
    });
  });

/**
 * (6) Reward claim approved / (7) rejected. Notifies the whole family.

 */
export const notifyOnRewardClaimUpdated = functions.firestore
  .document("rewardClaims/{claimId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!after || !after.familyId || !after.childId || !after.rewardId) return;

    const prevStatus = before?.status ?? "";
    const nextStatus = after.status ?? "";
    if (prevStatus === nextStatus) return;
    if (nextStatus !== "APPROVED" && nextStatus !== "REJECTED") return;
    if (prevStatus === "APPROVED" || prevStatus === "REJECTED") return;

    if (!isRecent(latest(after.approvedAt, after.claimedAt, after.updatedAt, after.createdAt))) return;

    const names = await resolveNames(after.childId, undefined, after.rewardId);
    const kid = safeString(names.childName, "Your kid");

    if (nextStatus === "APPROVED") {
      const reward = safeString(names.rewardName, "a reward");
      await notifyFamily({
        familyId: after.familyId,
        title: "Reward approved 🎉",
        body: `${kid} can redeem "${reward}"`,
        data: {
          type: "rewardApproved",
          familyId: after.familyId,
          claimId: context.params.claimId,
          childId: after.childId,
          rewardId: after.rewardId,
        },
      });
    } else {
      const reward = safeString(names.rewardName, "the reward");
      await notifyFamily({
        familyId: after.familyId,
        title: "Reward request declined",
        body: `${kid}: "${reward}" — ${safeString(after.notes, "Parent said not this time")}`,
        data: {
          type: "rewardRejected",
          familyId: after.familyId,
          claimId: context.params.claimId,
          childId: after.childId,
          rewardId: after.rewardId,
        },
      });
    }
  });

// ── POINTS TRIGGER ──

/**
 * (8) Manual point adjustments (bonus / deduct / set / reset( and
 * (9) reversals. Approvals already notify via the completion/claim triggers,
 * so their side-effect ledger entries are skipped to avoid duplicates (see
 * `SKIPPED_LEDGER_TYPES`(. Replaying a reversed original entry is also
 * skipped (that bookkeeping has no user-facing meaning(.
 */
export const notifyOnPointTransactionCreated = functions.firestore
  .document("pointTransactions/{transactionId}")
  .onCreate(async (snap, context) => {
    const tx = snap.data();
    if (!tx || !tx.familyId || !tx.childId || !tx.type) return;
    if (SKIPPED_LEDGER_TYPES.has(tx.type)) return;
    if (tx.isReversed) return;
    if (!isRecent(latest(tx.createdAt))) return;

    const names = await resolveNames(tx.childId);
    const kid = safeString(names.childName, "Your kid");
    const amount = typeof tx.amount === "number" ? tx.amount : 0;
    const delta = amount >= 0 ? `+${amount}⭐` : `${amount}⭐`;

    await notifyFamily({
      familyId: tx.familyId,
      title: amount >= 0 ? "Points added" : "Points deducted",
      body: `${kid} ${amount >= 0 ? "earned" : "lost"} ${delta} — ${safeString(tx.description, "Points updated")}`,
      data: {
        type: "pointsAdjusted",
        familyId: tx.familyId,
        transactionId: context.params.transactionId,
        childId: tx.childId,
        amount: String(tx.amount ?? 0),
      },
    });
  });

// ── CALLABLES ──

/**
 * Registers this device's FCM token for push delivery. Server-managed:the
 * app never writes `deviceTokens` directly (Firestore rules deny it), so a
 * token can only be registered by its authenticated owner. Treatupsert:
 * the same token re-registered (e.g. family switch( moves to the newest
 * family, and stale entries for a token are overwritten, never leaked.
 */
export const registerDeviceToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const token = String(data?.fcmToken ?? "").trim();
  if (token.length < 10 || token.length > 4096) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid FCM token");
  }
  const platform = String(data?.platform ?? "ios").trim() === "android" ? "android" : "ios";

  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "Not a family parent");
  }
  const familyId: unknown = parentDoc.data()?.familyId;
  if (typeof familyId !== "string" || !familyId) {
    throw new functions.https.HttpsError("permission-denied", "Not a family parent");
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("deviceTokens").doc(token).set({
    familyId,
    ownerUid: context.auth.uid,
    platform,
    createdAt: now,
    updatedAt: now,
  });
  return { ok: true };
});

/**
 * Removes a device token on sign-out. Only the token's owner (and family(
 * can delete it — cross-family/cross-user deletion is rejected.
 */
export const unregisterDeviceToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const token = String(data?.fcmToken ?? "").trim();
  if (!token || token.length > 4096) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid FCM token");
  }

  const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
  if (!parentDoc.exists) {
    return { ok: true };
  }
  const familyId: unknown = parentDoc.data()?.familyId;
  const tokenDoc = await db.collection("deviceTokens").doc(token).get();
  if (!tokenDoc.exists) {
    return { ok: true };
  }
  const tokenData = tokenDoc.data();
 if (
    typeof familyId === "string" &&
    tokenData?.familyId === familyId &&
    tokenData?.ownerUid === context.auth.uid
  ) {
    await db.collection("deviceTokens").doc(token).delete();
  }
  return { ok: true };
});
