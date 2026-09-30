import * as functions from "firebase-functions";
import * as crypto from "crypto";
import { admin, db } from "./firebase-init";
import {
  addWishlistItem,
  deleteWishlistItem,
  reviewWishlistItem,
  signKidToken,
  verifyKidToken,
  updateWishlistItem,
} from "./wishlist";
import {
  getWebPushPublicKey,
  registerWebPushSubscription,
  unregisterWebPushSubscription,
} from "./webpush";

export { addWishlistItem, updateWishlistItem, deleteWishlistItem, reviewWishlistItem };
export {
  getWebPushPublicKey,
  registerWebPushSubscription,
  unregisterWebPushSubscription,
};

/** Create family + parent docs after Auth signup. Client cannot write these collections. */
export const bootstrapFamily = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }

  const familyName = String(data.familyName || "Our family");
  const displayName = String(data.displayName || "Parent");
  const email = String(data.email || context.auth.token.email || "");
  const uid = context.auth.uid;
  const forceNewFamily = data?.forceNewFamily === true;

  const existing = await db.collection("parents").doc(uid).get();

  // Normal path: parent already has a family — return it (unless forcing a
  // clean slate after Reset / recovery, which must NEVER reuse the old id).
  if (existing.exists && !forceNewFamily) {
    return { familyId: existing.data()?.familyId, parentId: uid };
  }

  // Force-new or first-time: wipe any leftover docs for the previous family
  // so they cannot resurrect into the new session (duplicate kids/tasks bug).
  const previousFamilyId = existing.exists
    ? String(existing.data()?.familyId || "")
    : "";
  if (previousFamilyId && forceNewFamily) {
    const previousRole = String(existing.data()?.role || "parent");
    if (previousRole !== "owner") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only the family owner can reset this family"
      );
    }
    await deleteAllDocsForFamily(previousFamilyId);
    await db.collection("parents").doc(uid).delete().catch(() => {});
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
        // Wishlist (H1): default OFF for new families until parent enables it.
        enableWishlist: false,
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
    tx.set(db.collection("familyCodes").doc(familyCode), {
      familyId: familyRef.id,
      createdAt: now,
    });
    tx.set(db.collection("kidsPins").doc(kidsStationPIN), {
      familyId: familyRef.id,
      createdAt: now,
    });
  });

  return { familyId: familyRef.id, parentId: uid, kidsStationPIN, familyCode };
});

/** Simple Firestore-backed throttle for unauthenticated PIN attempts. */
async function assertPinAttemptAllowed(scope: string): Promise<void> {
  const ref = db.collection("pinAttemptGuards").doc(scope.slice(0, 120));
  const snap = await ref.get();
  const now = Date.now();
  const data = snap.data() || {};
  const windowStart = Number(data.windowStart || 0);
  const count = Number(data.count || 0);
  const WINDOW_MS = 15 * 60 * 1000;
  const MAX_ATTEMPTS = 20;
  if (now - windowStart > WINDOW_MS) {
    await ref.set({ windowStart: now, count: 1 }, { merge: true });
    return;
  }
  if (count >= MAX_ATTEMPTS) {
    throw new functions.https.HttpsError(
      "resource-exhausted",
      "Too many attempts. Try again later."
    );
  }
  await ref.set({ windowStart, count: count + 1 }, { merge: true });
}

async function clearPinAttemptGuard(scope: string): Promise<void> {
  await db.collection("pinAttemptGuards").doc(scope.slice(0, 120)).delete().catch(() => {});
}

/**
 * Kids Station PIN unlock (no parent password).
 * Looks up the family by Kids PIN and returns a kid-safe snapshot the iPad can
 * use without a parent Firebase Auth session.
 */
export const openKidsSession = functions.https.onCall(async (data, context) => {
  const pin = String(data?.pin || "").trim();
  if (!/^\d{4,6}$/.test(pin)) {
    throw new functions.https.HttpsError("invalid-argument", "Enter the family PIN");
  }

  const ip =
    (context.rawRequest?.headers?.["x-forwarded-for"] as string | undefined)?.split(",")[0]?.trim() ||
    (context.rawRequest?.ip as string | undefined) ||
    "unknown";
  await assertPinAttemptAllowed(`pin:${pin}`);
  await assertPinAttemptAllowed(`ip:${ip}`);

  const pinDoc = await db.collection("kidsPins").doc(pin).get();
  if (!pinDoc.exists) {
    // Fallback: scan families settings (legacy families without kidsPins index)
    const scan = await db.collection("families")
      .where("settings.kidsStationPIN", "==", pin)
      .limit(1)
      .get();
    if (scan.empty) {
      throw new functions.https.HttpsError("not-found", "Wrong PIN");
    }
    await clearPinAttemptGuard(`ip:${ip}`);
    return buildKidsSnapshot(scan.docs[0].id, scan.docs[0].data());
  }

  const familyId = String(pinDoc.data()?.familyId || "");
  const familyDoc = await db.collection("families").doc(familyId).get();
  if (!familyDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }
  await clearPinAttemptGuard(`ip:${ip}`);
  return buildKidsSnapshot(familyId, familyDoc.data() || {});
});

/** Strip server/parent-only fields before returning data to a kids session. */
function sanitizeKidsFamily(familyId: string, familyData: any) {
  const iso = (v: any) => {
    if (v && typeof v.toDate === "function") return v.toDate().toISOString();
    return v ?? null;
  };
  const settings = { ...(familyData?.settings || {}) };
  delete settings.kidsStationPIN;
  delete settings.plan;
  // iOS Family Codable reads `members` (not memberIds).
  return {
    id: familyId,
    name: familyData?.name,
    members: familyData?.members ?? familyData?.memberIds ?? [],
    settings: {
      pointDisplaySymbol: settings.pointDisplaySymbol ?? "⭐",
      enableNotifications: settings.enableNotifications ?? true,
      celebrationAnimationsEnabled: settings.celebrationAnimationsEnabled ?? true,
      requireApprovalByDefault: settings.requireApprovalByDefault ?? true,
      weekStartsOn: settings.weekStartsOn ?? 1,
      enableWishlist: settings.enableWishlist === true,
    },
    createdAt: iso(familyData?.createdAt),
    updatedAt: iso(familyData?.updatedAt),
    serverUpdatedAt: iso(familyData?.serverUpdatedAt),
  };
}

async function buildKidsSnapshot(familyId: string, familyData: any) {
  const family = sanitizeKidsFamily(familyId, familyData);

  const col = async (name: string) => {
    const snap = await db.collection(name).where("familyId", "==", familyId).get();
    return snap.docs.map((d) => {
      const row: any = { id: d.id, ...d.data() };
      for (const key of Object.keys(row)) {
        if (row[key] && typeof row[key].toDate === "function") {
          row[key] = row[key].toDate().toISOString();
        }
      }
      // Only strip parent UIDs from the ledger. Tasks/rewards require
      // `createdBy` on the client Codable — do not remove those fields.
      if (name === "pointTransactions") {
        delete row.createdBy;
        delete row.approvedBy;
        delete row.reviewedBy;
      }
      return row;
    });
  };

  const [children, tasks, completions, rewards, claims, transactions, achievements, wishlistItems] =
    await Promise.all([
      col("children"),
      col("tasks"),
      col("taskCompletions"),
      col("rewards"),
      col("rewardClaims"),
      col("pointTransactions"),
      col("achievements"),
      col("wishlistItems"),
    ]);

  const wishlistEnabled = familyData?.settings?.enableWishlist === true;
  // Kid session token for wishlist callables (separate from parent Auth).
  const kidsAccessToken = signKidToken({ familyId });

  return {
    familyId,
    family,
    children,
    tasks,
    completions,
    rewards,
    claims,
    transactions,
    achievements,
    wishlistItems,
    wishlistEnabled,
    kidsAccessToken,
  };
}

/**
 * Parent-only: rotate Kids PIN and update the lookup index.
 */
export const updateKidsStationPIN = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const uid = context.auth.uid;
  const pin = String(data?.pin || "").trim();
  const previousPin = String(data?.previousPin || "").trim();
  if (!/^\d{4,6}$/.test(pin)) {
    throw new functions.https.HttpsError("invalid-argument", "PIN must be 4–6 digits");
  }
  const parentDoc = await db.collection("parents").doc(uid).get();
  if (!parentDoc.exists) {
    throw new functions.https.HttpsError("permission-denied", "Not a parent");
  }
  const familyId = parentDoc.data()?.familyId;
  if (!familyId) {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }

  // Ownership: never steal another family's PIN mapping.
  const existingPinDoc = await db.collection("kidsPins").doc(pin).get();
  if (existingPinDoc.exists && existingPinDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError(
      "already-exists",
      "That PIN is already in use. Choose another."
    );
  }

  const batch = db.batch();
  batch.update(db.collection("families").doc(familyId), {
    "settings.kidsStationPIN": pin,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    serverUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("kidsPins").doc(pin), {
    familyId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  if (previousPin && previousPin !== pin) {
    const stale = await db.collection("kidsPins").doc(previousPin).get();
    if (stale.exists && stale.data()?.familyId === familyId) {
      batch.delete(db.collection("kidsPins").doc(previousPin));
    }
  }
  await batch.commit();
  return { ok: true, pin };
});

/**
 * Deletes every family-scoped document for `familyId` (paginated, batched).
 * Used by deleteFamilyData and by bootstrapFamily(forceNewFamily).
 */
async function deleteAllDocsForFamily(familyId: string): Promise<void> {
  if (!familyId) return;
  const collections = [
    "children",
    "tasks",
    "taskCompletions",
    "rewards",
    "rewardClaims",
    "pointTransactions",
    "achievements",
    "taskInstances",
    "wishlistItems",
  ];

  for (const collection of collections) {
    // Loop until empty so we never stop at the first page / 500-op batch limit.
    for (;;) {
      const snap = await db
        .collection(collection)
        .where("familyId", "==", familyId)
        .limit(400)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  // Drop join-code index entries that still point at this family.
  const codes = await db
    .collection("familyCodes")
    .where("familyId", "==", familyId)
    .limit(400)
    .get();
  if (!codes.empty) {
    const batch = db.batch();
    codes.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  // Device tokens are keyed by fcmToken with familyId field — best-effort.
  const tokens = await db
    .collection("deviceTokens")
    .where("familyId", "==", familyId)
    .limit(400)
    .get();
  if (!tokens.empty) {
    const batch = db.batch();
    tokens.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  await db.collection("families").doc(familyId).delete();
}

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

  const email = String(context.auth.token.email || "").trim().toLowerCase();
  const OWNER_EMAILS = new Set(["xxarzelxx@gmail.com"]);
  const displayName = String(data?.displayName || "Parent");
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Server-side premium check (owner exempt). Client UI gates are UX only.
  const isOwner = OWNER_EMAILS.has(email);
  if (!isOwner) {
    const plan = String(familyDoc.data()?.settings?.plan || "").toLowerCase();
    const premiumPlan = plan === "plus" || plan === "pro";
    let hasActiveSub = false;
    if (!premiumPlan) {
      const subs = await db
        .collection("subscriptions")
        .where("familyId", "==", familyId)
        .where("status", "==", "active")
        .limit(1)
        .get();
      hasActiveSub = !subs.empty;
    }
    if (!premiumPlan && !hasActiveSub) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Co-parent join requires Premium on this family."
      );
    }
  }

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

  return {
    familyId,
    parentId: uid,
    alreadyMember: false,
    ownerAllowed: isOwner,
  };
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
  const name = String(data.name || "Kid").trim().slice(0, 60);
  if (!name) {
    throw new functions.https.HttpsError("invalid-argument", "Name is required");
  }

  // Free-plan child limit (server-side). Owner / premium unlimited.
  const email = String(context.auth.token.email || "").toLowerCase();
  const isOwner = ["xxarzelxx@gmail.com"].includes(email);
  const familySnap = await db.collection("families").doc(familyId).get();
  const plan = String(familySnap.data()?.settings?.plan || "").toLowerCase();
  const premium = isOwner || plan === "plus" || plan === "pro";
  if (!premium) {
    const kidsSnap = await db
      .collection("children")
      .where("familyId", "==", familyId)
      .limit(50)
      .get();
    if (kidsSnap.size >= 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Free plan includes 1 kid. Upgrade to Premium for more."
      );
    }
  }

  const childRef = db.collection("children").doc();
  await childRef.set({
    name,
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

/** Resolve parent Auth or kids HMAC session to a familyId. */
async function resolveFamilyActor(
  data: any,
  context: functions.https.CallableContext
): Promise<{ familyId: string; parentUid: string | null }> {
  const familyId = String(data?.familyId || "").trim();
  const tokenPayload = verifyKidToken(data?.kidsAccessToken);
  if (context.auth) {
    if (!familyId) {
      throw new functions.https.HttpsError("invalid-argument", "familyId is required");
    }
    const parentDoc = await db.collection("parents").doc(context.auth.uid).get();
    if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
      throw new functions.https.HttpsError("permission-denied", "Not authorized");
    }
    return { familyId, parentUid: context.auth.uid };
  }
  if (!tokenPayload) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in as a parent or unlock Kids Station"
    );
  }
  if (familyId && tokenPayload.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Session family mismatch");
  }
  return { familyId: tokenPayload.familyId, parentUid: null };
}

/** Bump family timestamps so iOS/other clients refresh immediately. */
async function touchFamily(familyId: string): Promise<void> {
  // sync-v2: ensure web-authored completions propagate to iOS
  await db.collection("families").doc(familyId).set(
    {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      serverUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export const submitTaskCompletion = functions.https.onCall(async (data, context) => {
  const actor = await resolveFamilyActor(data, context);
  const familyId = actor.familyId;
  const { taskId, childId } = data;
  if (!taskId || !childId) {
    throw new functions.https.HttpsError("invalid-argument", "taskId and childId are required");
  }
  const taskDoc = await db.collection("tasks").doc(String(taskId)).get();
  if (!taskDoc.exists || taskDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("not-found", "Task not found");
  }
  const childCheck = await db.collection("children").doc(String(childId)).get();
  if (!childCheck.exists || childCheck.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("permission-denied", "Child not in family");
  }
  const requiresApproval = taskDoc.data()?.requiresApproval !== false;

  // Kid-reported day (today / yesterday / other). Fall back to server now.
  const rawCompletedAt = String(data?.completedAt || "").trim();
  const parsedCompletedAt = rawCompletedAt ? new Date(rawCompletedAt) : null;
  const completedAtValue =
    parsedCompletedAt && !Number.isNaN(parsedCompletedAt.getTime())
      ? admin.firestore.Timestamp.fromDate(parsedCompletedAt)
      : admin.firestore.FieldValue.serverTimestamp();

  // Reject duplicate open completions for the same task/child (point-farm guard).
  const dupSnap = await db
    .collection("taskCompletions")
    .where("familyId", "==", familyId)
    .where("taskId", "==", String(taskId))
    .where("childId", "==", String(childId))
    .limit(20)
    .get();
  const openDup = dupSnap.docs.find((d) => {
    const s = String(d.data()?.status || "");
    return s === "AWAITING_APPROVAL" || s === "COMPLETED" || s === "APPROVED";
  });
  if (openDup) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Already submitted for this mission"
    );
  }

  const completionRef = db.collection("taskCompletions").doc();
  const autoApprove = !requiresApproval;
  const pointValue = Number(taskDoc.data()?.pointValue ?? 0);

  if (autoApprove && pointValue > 0) {
    const txId = db.collection("pointTransactions").doc().id;
    await db.runTransaction(async (tx) => {
      tx.set(completionRef, {
        familyId,
        taskId: String(taskId),
        childId: String(childId),
        status: "APPROVED",
        completedAt: completedAtValue,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: actor.parentUid || "kids-session",
        pointsAwarded: pointValue,
        pointTransactionId: txId,
      });
      tx.set(db.collection("pointTransactions").doc(txId), {
        familyId,
        childId: String(childId),
        amount: pointValue,
        type: "TASK_COMPLETION",
        relatedId: completionRef.id,
        description: `Task completed: ${taskDoc.data()?.name || ""}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: actor.parentUid || "kids-session",
        isReversed: false,
      });
      tx.update(db.collection("children").doc(String(childId)), {
        activePoints: admin.firestore.FieldValue.increment(pointValue),
        totalPointsEarned: admin.firestore.FieldValue.increment(pointValue),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await touchFamily(familyId);
    return { completionId: completionRef.id, status: "APPROVED", pointsAwarded: pointValue };
  }

  await completionRef.set({
    familyId,
    taskId: String(taskId),
    childId: String(childId),
    status: requiresApproval ? "AWAITING_APPROVAL" : "COMPLETED",
    completedAt: completedAtValue,
  });
  // Bump family stamp so other devices (iOS) refresh promptly.
  await touchFamily(familyId);
  return { completionId: completionRef.id, status: requiresApproval ? "AWAITING_APPROVAL" : "COMPLETED" };
});

export const claimReward = functions.https.onCall(async (data, context) => {
  const actor = await resolveFamilyActor(data, context);
  const familyId = actor.familyId;
  const { rewardId, childId } = data;
  if (!rewardId || !childId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
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
  const activePoints = Number(childDoc.data()?.activePoints ?? 0);
  const pointCost = Number(rewardDoc.data()?.pointCost ?? 0);
  if (pointCost > 0 && activePoints < pointCost) {
    throw new functions.https.HttpsError("failed-precondition", "Insufficient points");
  }

  // One open claim per reward/child.
  const openClaims = await db
    .collection("rewardClaims")
    .where("familyId", "==", familyId)
    .where("rewardId", "==", String(rewardId))
    .where("childId", "==", String(childId))
    .limit(10)
    .get();
  const openClaim = openClaims.docs.find((d) => {
    const s = String(d.data()?.status || "");
    return s === "CLAIMED" || s === "APPROVED";
  });
  if (openClaim) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Already requested this reward"
    );
  }

  const claimRef = db.collection("rewardClaims").doc();
  await claimRef.set({
    familyId,
    rewardId,
    childId,
    status: "CLAIMED",
    claimedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await touchFamily(familyId);
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
  await touchFamily(familyId);
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
      const uid = context.auth.uid;
      // Verify parent owns this family
      const parentDoc = await db.collection("parents").doc(uid).get();
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

      // Transaction: re-check status so concurrent approvals cannot double-award.
      const transactionId = db.collection("pointTransactions").doc().id;
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(db.collection("taskCompletions").doc(completionId));
        if (!snap.exists) {
          throw new functions.https.HttpsError("not-found", "Completion not found");
        }
        const current = snap.data() || {};
        if (current.status === "APPROVED") {
          throw new functions.https.HttpsError("already-exists", "Task already approved");
        }
        if (typeof current.familyId === "string" && current.familyId !== familyId) {
          throw new functions.https.HttpsError("permission-denied", "Completion not in family");
        }
        tx.set(db.collection("pointTransactions").doc(transactionId), {
          familyId,
          childId,
          amount: awardedPoints,
          type: "TASK_COMPLETION",
          relatedId: completionId,
          description: `Task completed: ${data.taskName || ""}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: uid,
          isReversed: false,
        });
        tx.update(db.collection("taskCompletions").doc(completionId), {
          status: "APPROVED",
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          approvedBy: uid,
          pointsAwarded: awardedPoints,
          pointTransactionId: transactionId,
        });
        tx.update(db.collection("children").doc(childId), {
          activePoints: admin.firestore.FieldValue.increment(awardedPoints),
          totalPointsEarned: admin.firestore.FieldValue.increment(awardedPoints),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await touchFamily(familyId);
      return {
        success: true,
        transactionId,
        message: "Task approved and points awarded",
      };
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error("Error approving task:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Could not approve task"
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

      await touchFamily(familyId);
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
      const uid = context.auth.uid;
      // Verify parent owns this family
      const parentDoc = await db.collection("parents").doc(uid).get();
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

      const deductionTransactionId = db.collection("pointTransactions").doc().id;
      await db.runTransaction(async (tx) => {
        const claimSnap = await tx.get(db.collection("rewardClaims").doc(String(claimId)));
        if (!claimSnap.exists) {
          throw new functions.https.HttpsError("not-found", "Claim not found");
        }
        const claim = claimSnap.data() || {};
        if (claim.status === "APPROVED") {
          throw new functions.https.HttpsError(
            "already-exists",
            "Reward claim already approved"
          );
        }
        if (typeof claim.familyId === "string" && claim.familyId !== familyId) {
          throw new functions.https.HttpsError("permission-denied", "Claim not in family");
        }
        const childSnap = await tx.get(db.collection("children").doc(String(childId)));
        const balance = Number(childSnap.data()?.activePoints ?? 0);
        if (balance < deductionCost) {
          throw new functions.https.HttpsError("failed-precondition", "Insufficient points");
        }
        tx.set(db.collection("pointTransactions").doc(deductionTransactionId), {
          familyId,
          childId,
          amount: -deductionCost,
          type: "REWARD_REDEMPTION",
          relatedId: claimId,
          description: `Reward claimed: ${data.rewardName || ""}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: uid,
          isReversed: false,
        });
        tx.update(db.collection("rewardClaims").doc(String(claimId)), {
          status: "APPROVED",
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          approvedBy: uid,
          pointDeductionTransactionId: deductionTransactionId,
        });
        tx.update(db.collection("children").doc(String(childId)), {
          activePoints: admin.firestore.FieldValue.increment(-deductionCost),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await touchFamily(familyId);
      return {
        success: true,
        transactionId: deductionTransactionId,
        message: "Reward approved",
      };
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error("Error approving reward:", error);
      throw new functions.https.HttpsError("internal", "Could not approve reward");
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
    wishlistItems: [],
  };

  const collectionMap: Record<string, string> = {
    children: "children",
    tasks: "tasks",
    completions: "taskCompletions",
    rewards: "rewards",
    claims: "rewardClaims",
    transactions: "pointTransactions",
    achievements: "achievements",
    wishlistItems: "wishlistItems",
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

  const tombstoneId = (collectionKey: string, docId: string) =>
    `${familyId}:${collectionKey}:${docId}`;

  const TERMINAL_STATUSES = new Set(["APPROVED", "REJECTED", "COMPLETED", "RECEIVED"]);
  const PENDING_STATUSES = new Set(["AWAITING_APPROVAL", "CLAIMED", "PENDING"]);

  const upsert = async (collection: string, items: any[], collectionKey: string) => {
    for (const item of items || []) {
      if (!item || typeof item.id !== "string") continue;
      if (typeof item.familyId === "string" && item.familyId !== familyId) continue;
      // Skip docs deleted from another client (e.g. web) — do not resurrect.
      const tomb = await db
        .collection("familyTombstones")
        .doc(tombstoneId(collectionKey, item.id))
        .get();
      if (tomb.exists) continue;

      // Never overwrite another family's document by ID (cross-tenant write).
      const existingOwned = await db.collection(collection).doc(item.id).get();
      if (existingOwned.exists) {
        const existingFamily = existingOwned.data()?.familyId;
        if (typeof existingFamily === "string" && existingFamily !== familyId) {
          continue;
        }
      }

      let payload = { ...item, familyId };

      // Approval statuses are terminal: a stale full-snapshot push must never
      // flip APPROVED/REJECTED back to AWAITING_APPROVAL / CLAIMED.
      if (collectionKey === "completions" || collectionKey === "claims") {
        const existing = await db.collection(collection).doc(item.id).get();
        if (existing.exists) {
          const prev = String(existing.data()?.status || "");
          const next = String(item.status || "");
          if (TERMINAL_STATUSES.has(prev) && PENDING_STATUSES.has(next)) {
            const { status: _drop, ...rest } = item;
            payload = { ...rest, familyId, status: prev };
          }
        }
      }

      batch.set(
        db.collection(collection).doc(item.id),
        toFirestoreValue(payload),
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
    // Server-owned fields: never accept plan/billing from clients.
    if (familyPayload.settings && typeof familyPayload.settings === "object") {
      delete familyPayload.settings.plan;
      delete familyPayload.settings.billing;
    }
    delete familyPayload.familyCode;
    batch.set(
      db.collection("families").doc(familyId),
      { ...familyPayload, updatedAt: now, serverUpdatedAt: now },
      { merge: true }
    );
    batchCount += 1;

    // Keep familyCode index in sync for co-parent join (never steal another family's code).
    const code = typeof data.family.familyCode === "string"
      ? String(data.family.familyCode).trim().toUpperCase()
      : "";
    if (code) {
      const codeDoc = await db.collection("familyCodes").doc(code).get();
      if (!codeDoc.exists || codeDoc.data()?.familyId === familyId) {
        batch.set(
          db.collection("familyCodes").doc(code),
          { familyId, updatedAt: now },
          { merge: true }
        );
        batchCount += 1;
      }
    }

    // Keep kidsPins index in sync when the client pushes a PIN (ownership-checked).
    const pushedPin = data.family?.settings?.kidsStationPIN
      ? String(data.family.settings.kidsStationPIN).trim()
      : "";
    if (/^\d{4,6}$/.test(pushedPin)) {
      const existingPinSnap = await db.collection("kidsPins").doc(pushedPin).get();
      if (existingPinSnap.exists && existingPinSnap.data()?.familyId !== familyId) {
        throw new functions.https.HttpsError(
          "already-exists",
          "That PIN is already in use. Choose another."
        );
      }
      const existingFamilySnap = await db.collection("families").doc(familyId).get();
      const previousPin = String(existingFamilySnap.data()?.settings?.kidsStationPIN || "").trim();
      batch.set(
        db.collection("kidsPins").doc(pushedPin),
        { familyId, updatedAt: now },
        { merge: true }
      );
      batchCount += 1;
      if (previousPin && previousPin !== pushedPin) {
        const stale = await db.collection("kidsPins").doc(previousPin).get();
        if (stale.exists && stale.data()?.familyId === familyId) {
          batch.delete(db.collection("kidsPins").doc(previousPin));
          batchCount += 1;
        }
      }
    }
  }

  // Free-plan task limit (count after upsert would be too late — check payload).
  const familyForLimits = await db.collection("families").doc(familyId).get();
  const plan = String(familyForLimits.data()?.settings?.plan || "").toLowerCase();
  const isPremium = plan === "plus" || plan === "pro";
  if (!isPremium && Array.isArray(data?.tasks) && data.tasks.length > 20) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Free plan includes 20 chores. Upgrade to Premium for more."
    );
  }

  await upsert("children", data?.children, "children");
  await upsert("tasks", data?.tasks, "tasks");
  await upsert("taskCompletions", data?.completions, "completions");
  await upsert("rewards", data?.rewards, "rewards");
  await upsert("rewardClaims", data?.claims, "claims");
  await upsert("pointTransactions", data?.transactions, "transactions");
  await upsert("achievements", data?.achievements, "achievements");
  await upsert("wishlistItems", data?.wishlistItems, "wishlistItems");

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
  const role = String(parentDoc.data()?.role || "parent");
  if (role !== "owner") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only the family owner can delete all family data"
    );
  }
  const familyId = parentDoc.data()?.familyId;
  if (!familyId || typeof familyId !== "string") {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }

  // Thorough wipe (paginated). Partial deletes previously left orphan kids/
  // tasks that resurrected on the next pull (duplicates after reset).
  await deleteAllDocsForFamily(familyId);
  await db.collection("parents").doc(uid).delete();

  return { ok: true, familyId };
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
        const taskId = taskDoc.id;

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
            // Weekly on Mondays (calendar week start).
            shouldCreate = today.getDay() === 1;
            break;
        }

        if (shouldCreate && Array.isArray(task.assignedChildIds) && task.assignedChildIds.length > 0) {
          const dateKey = today.toISOString().split("T")[0];
          for (const childId of task.assignedChildIds) {
            const instanceId = `${taskId}_${childId}_${dateKey}`;
            const instanceRef = db.collection("taskInstances").doc(instanceId);
            const existing = await instanceRef.get();
            if (existing.exists) continue;
            await instanceRef.create({
              taskId,
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
 * Generate a random 6-digit Kids Station PIN (CSPRNG).
 */
function generateKidsPIN(): string {
  return String(crypto.randomInt(100000, 1000000));
}

/** Human-friendly co-parent join code, e.g. KDO-4F7X. */
function generateFamilyCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let suffix = "";
  for (let i = 0; i < 5; i++) {
    suffix += alphabet.charAt(crypto.randomInt(0, alphabet.length));
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
