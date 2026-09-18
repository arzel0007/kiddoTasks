import * as functions from "firebase-functions";
import * as crypto from "crypto";
import { admin, db } from "./firebase-init";

export type WishlistStatus = "PENDING" | "APPROVED" | "REJECTED" | "RECEIVED";

export const WISHLIST_STATUSES: WishlistStatus[] = [
  "PENDING",
  "APPROVED",
  "REJECTED",
  "RECEIVED",
];

export const WISHLIST_OCCASIONS = [
  "BIRTHDAY",
  "CHRISTMAS",
  "GRADUATION",
  "SCHOOL",
  "SPECIAL",
  "JUST_BECAUSE",
  "OTHER",
] as const;

function kidSessionSecret(): string {
  const configured = process.env.KID_SESSION_SECRET;
  if (configured && configured.length >= 16) return configured;
  const projectId =
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "kiddotasks-app";
  // Emulator / missing config only — set KID_SESSION_SECRET in production.
  return `dev-kid-session-${projectId}`;
}

function b64url(input: string | Buffer): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export type KidTokenPayload = {
  familyId: string;
  childId?: string | null;
  exp: number;
};

export function signKidToken(
  payload: Omit<KidTokenPayload, "exp">,
  ttlSeconds = 12 * 60 * 60
): string {
  const body = b64url(
    JSON.stringify({
      familyId: payload.familyId,
      childId: payload.childId ?? null,
      exp: Math.floor(Date.now() / 1000) + ttlSeconds,
    })
  );
  const sig = b64url(
    crypto.createHmac("sha256", kidSessionSecret()).update(body).digest()
  );
  return `${body}.${sig}`;
}

export function verifyKidToken(token: unknown): KidTokenPayload | null {
  if (typeof token !== "string" || !token.includes(".")) return null;
  const [body, sig] = token.split(".");
  if (!body || !sig) return null;
  const expected = b64url(
    crypto.createHmac("sha256", kidSessionSecret()).update(body).digest()
  );
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const json = JSON.parse(
      Buffer.from(body.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8")
    ) as KidTokenPayload;
    if (!json?.familyId || typeof json.exp !== "number") return null;
    if (json.exp * 1000 < Date.now()) return null;
    return json;
  } catch {
    return null;
  }
}

function isWishlistEnabled(familyData: any): boolean {
  // Product decision H1: default OFF for existing + new families.
  return familyData?.settings?.enableWishlist === true;
}

async function loadFamilyDoc(familyId: string) {
  const snap = await db.collection("families").doc(familyId).get();
  if (!snap.exists) return null;
  return snap.data() || null;
}

async function assertParentInFamily(
  uid: string | undefined,
  familyId: string
): Promise<void> {
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }
  const parentDoc = await db.collection("parents").doc(uid).get();
  if (!parentDoc.exists || parentDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Not authorized for this family"
    );
  }
}

async function assertChildInFamily(childId: string, familyId: string) {
  const childDoc = await db.collection("children").doc(childId).get();
  if (!childDoc.exists || childDoc.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Child not in this family"
    );
  }
  return childDoc.data() || {};
}

/**
 * Resolve acting family for wishlist mutations.
 * Accepts either a parent Firebase Auth session or a kid-session HMAC token.
 */
async function resolveWishlistActor(
  data: any,
  context: functions.https.CallableContext
): Promise<{
  familyId: string;
  mode: "parent" | "kid";
  parentUid: string | null;
  childId: string | null;
  familyData: any;
}> {
  const familyId = String(data?.familyId || "").trim();
  const childId = data?.childId ? String(data.childId) : null;
  const tokenPayload = verifyKidToken(data?.kidsAccessToken);

  if (context.auth) {
    if (!familyId) {
      throw new functions.https.HttpsError("invalid-argument", "familyId is required");
    }
    await assertParentInFamily(context.auth.uid, familyId);
    const familyData = await loadFamilyDoc(familyId);
    if (!familyData) {
      throw new functions.https.HttpsError("not-found", "Family not found");
    }
    return {
      familyId,
      mode: "parent",
      parentUid: context.auth.uid,
      childId,
      familyData,
    };
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
  const resolvedFamilyId = tokenPayload.familyId;
  const resolvedChildId = childId || tokenPayload.childId || null;
  const familyData = await loadFamilyDoc(resolvedFamilyId);
  if (!familyData) {
    throw new functions.https.HttpsError("not-found", "Family not found");
  }
  return {
    familyId: resolvedFamilyId,
    mode: "kid",
    parentUid: null,
    childId: resolvedChildId,
    familyData,
  };
}

function assertWishlistEnabled(familyData: any) {
  if (!isWishlistEnabled(familyData)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Wishlist is turned off. Ask a parent to enable it."
    );
  }
}

/**
 * Kid / parent add wishlist item — NEVER touches points.
 */
export const addWishlistItem = functions.https.onCall(async (data, context) => {
  try {
    const actor = await resolveWishlistActor(data, context);
    assertWishlistEnabled(actor.familyData);

    const title = String(data?.title || "").trim();
    if (!title || title.length > 120) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Item name is required (max 120 characters)."
      );
    }
    const message = String(data?.message || "").trim().slice(0, 500);
    const rawOccasion = data?.occasion != null ? String(data.occasion) : null;
    const occasion =
      rawOccasion && (WISHLIST_OCCASIONS as readonly string[]).includes(rawOccasion)
        ? rawOccasion
        : null;

    const childId = actor.childId;
    if (!childId) {
      throw new functions.https.HttpsError("invalid-argument", "childId is required");
    }
    await assertChildInFamily(childId, actor.familyId);

    const now = admin.firestore.FieldValue.serverTimestamp();
    const ref = db.collection("wishlistItems").doc();
    const doc = {
      id: ref.id,
      familyId: actor.familyId,
      childId,
      title,
      message,
      occasion,
      status: "PENDING" as WishlistStatus,
      parentResponse: null,
      createdBy: actor.parentUid || "kids-session",
      createdAt: now,
      updatedAt: now,
      reviewedAt: null,
      reviewedBy: null,
      version: 1,
    };
    await ref.set(doc);
    return { id: ref.id, status: doc.status };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    console.error("[wishlist] addWishlistItem failed", e);
    throw new functions.https.HttpsError(
      "internal",
      "Wishlist service failed. Check function logs after deploy --only functions."
    );
  }
});

/**
 * Update wishlist item fields (kid: own PENDING only; parent: any in family, title/message/occasion only).
 */
export const updateWishlistItem = functions.https.onCall(async (data, context) => {
  const itemId = String(data?.itemId || "").trim();
  if (!itemId) {
    throw new functions.https.HttpsError("invalid-argument", "itemId is required");
  }
  const actor = await resolveWishlistActor(data, context);
  const ref = db.collection("wishlistItems").doc(itemId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.familyId !== actor.familyId) {
    throw new functions.https.HttpsError("not-found", "Wishlist item not found");
  }
  const existing = snap.data() || {};

  if (actor.mode === "kid") {
    assertWishlistEnabled(actor.familyData);
    if (!actor.childId || existing.childId !== actor.childId) {
      throw new functions.https.HttpsError("permission-denied", "Not your wishlist item");
    }
    if (existing.status !== "PENDING") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Only waiting items can be edited"
      );
    }
  }

  const title = String(data?.title ?? existing.title ?? "").trim();
  if (!title || title.length > 120) {
    throw new functions.https.HttpsError("invalid-argument", "Item name is required.");
  }
  const message = String(data?.message ?? existing.message ?? "")
    .trim()
    .slice(0, 500);
  const rawOccasion =
    data?.occasion !== undefined ? data.occasion : existing.occasion;
  const occasion =
    rawOccasion && (WISHLIST_OCCASIONS as readonly string[]).includes(String(rawOccasion))
      ? String(rawOccasion)
      : null;

  const expectedVersion =
    typeof data?.version === "number" ? Number(data.version) : null;
  if (expectedVersion != null && existing.version !== expectedVersion) {
    throw new functions.https.HttpsError(
      "aborted",
      "This item changed — refresh and try again"
    );
  }

  await ref.update({
    title,
    message,
    occasion,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    version: (existing.version || 1) + 1,
  });
  return { id: itemId, status: existing.status };
});

/**
 * Delete wishlist item.
 * Kid: own PENDING or REJECTED. Parent: any in family.
 * Does not touch points.
 */
export const deleteWishlistItem = functions.https.onCall(async (data, context) => {
  const itemId = String(data?.itemId || "").trim();
  if (!itemId) {
    throw new functions.https.HttpsError("invalid-argument", "itemId is required");
  }
  const actor = await resolveWishlistActor(data, context);
  const ref = db.collection("wishlistItems").doc(itemId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.familyId !== actor.familyId) {
    throw new functions.https.HttpsError("not-found", "Wishlist item not found");
  }
  const existing = snap.data() || {};

  if (actor.mode === "kid") {
    if (!actor.childId || existing.childId !== actor.childId) {
      throw new functions.https.HttpsError("permission-denied", "Not your wishlist item");
    }
    if (existing.status !== "PENDING" && existing.status !== "REJECTED") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "You can only remove waiting or rejected items"
      );
    }
  }

  await ref.delete();
  await db
    .collection("familyTombstones")
    .doc(`${actor.familyId}:wishlistItems:${itemId}`)
    .set({
      familyId: actor.familyId,
      collectionName: "wishlistItems",
      docId: itemId,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  return { ok: true };
});

/**
 * Parent approve/reject — separate from points/rewards economy.
 * Must NOT update children.activePoints or create pointTransactions.
 */
export const reviewWishlistItem = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Parent sign-in required");
  }
  const familyId = String(data?.familyId || "").trim();
  const itemId = String(data?.itemId || "").trim();
  const decision = String(data?.decision || "").toUpperCase();
  if (!familyId || !itemId) {
    throw new functions.https.HttpsError("invalid-argument", "familyId and itemId are required");
  }
  if (decision !== "APPROVED" && decision !== "REJECTED") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "decision must be APPROVED or REJECTED"
    );
  }
  await assertParentInFamily(context.auth.uid, familyId);

  const ref = db.collection("wishlistItems").doc(itemId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.familyId !== familyId) {
    throw new functions.https.HttpsError("not-found", "Wishlist item not found");
  }
  const existing = snap.data() || {};
  if (existing.status === "APPROVED" || existing.status === "REJECTED") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This wishlist item was already reviewed"
    );
  }
  if (existing.status === "RECEIVED") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "This wishlist item is already marked received"
    );
  }

  const parentResponse =
    data?.parentResponse != null
      ? String(data.parentResponse).trim().slice(0, 500)
      : null;
  const expectedVersion =
    typeof data?.version === "number" ? Number(data.version) : null;
  if (expectedVersion != null && existing.version !== expectedVersion) {
    throw new functions.https.HttpsError(
      "aborted",
      "This item changed — refresh and try again"
    );
  }

  await ref.update({
    status: decision,
    parentResponse,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    version: (existing.version || 1) + 1,
  });

  // CRITICAL: do not write children, rewardClaims, or pointTransactions.
  return { id: itemId, status: decision };
});
