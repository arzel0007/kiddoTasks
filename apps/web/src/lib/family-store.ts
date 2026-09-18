"use client";

import { create } from "zustand";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { firebaseFunctions, firestore, isFirebaseConfigured } from "./firebase";
import type {
  Child,
  Family,
  KiddoTask,
  PointTransaction,
  Reward,
  RewardClaim,
  TaskCompletion,
  Entitlements,
  TaskApprovalBehavior,
  TaskRecurrenceType,
  WishlistItem,
  WishlistStatus,
} from "./types";
import { canAddTask, isOwnerEmail } from "./entitlements";
import { requiresApprovalFromBehavior } from "./catalog";
import { errorMessage } from "./errors";
import { isWishlistEnabled } from "./wishlist";

/** Normalize Firestore timestamp-like values to ISO strings. */
function toIso(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value === "string") return value;
  if (
    typeof value === "object" &&
    typeof (value as { toDate?: () => Date }).toDate === "function"
  ) {
    try {
      return (value as { toDate: () => Date }).toDate().toISOString();
    } catch {
      return null;
    }
  }
  return null;
}

function mapWishlistDoc(id: string, data: Record<string, unknown>): WishlistItem {
  return {
    id,
    familyId: String(data.familyId ?? ""),
    childId: String(data.childId ?? ""),
    title: String(data.title ?? ""),
    message: data.message == null ? null : String(data.message),
    occasion: data.occasion == null ? null : String(data.occasion),
    status: (data.status as WishlistStatus) || "PENDING",
    parentResponse:
      data.parentResponse == null ? null : String(data.parentResponse),
    createdBy: String(data.createdBy ?? ""),
    createdAt: toIso(data.createdAt),
    updatedAt: toIso(data.updatedAt),
    reviewedAt: toIso(data.reviewedAt),
    reviewedBy: data.reviewedBy == null ? null : String(data.reviewedBy),
    version: typeof data.version === "number" ? data.version : 1,
  };
}

function mapWishlistCallableError(name: string, err: unknown): string {
  const code = String(
    (err as { code?: unknown }).code ?? (err as { message?: unknown }).message ?? ""
  );
  const message = String((err as { message?: unknown }).message ?? "");
  if (/not-found|NOT_FOUND|404|UNIMPLEMENTED|unimplemented/i.test(`${code} ${message}`)) {
    return `Wishlist cloud function “${name}” is not deployed. Run: firebase deploy --only functions`;
  }
  if (/internal|INTERNAL|500/i.test(`${code} ${message}`)) {
    return `Wishlist service error (${name}). Deploy Firebase Functions, then try again.`;
  }
  if (/permission|PERMISSION/i.test(`${code} ${message}`)) {
    return message || "Not allowed for this family.";
  }
  if (/failed-precondition|Wishlist is turned off/i.test(`${code} ${message}`)) {
    return message || "Wishlist is turned off.";
  }
  return errorMessage(err, `Couldn’t reach wishlist service (${name}).`);
}

async function callWishlistFn(
  name: string,
  payload: Record<string, unknown>
): Promise<Record<string, unknown>> {
  if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
  const fn = httpsCallable(firebaseFunctions(), name);
  try {
    const res = await fn(payload);
    return (res.data ?? {}) as Record<string, unknown>;
  } catch (e) {
    throw new Error(mapWishlistCallableError(name, e));
  }
}

type FamilyState = {
  loading: boolean;
  error: string | null;
  family: Family | null;
  parentUid: string | null;
  children: Child[];
  tasks: KiddoTask[];
  completions: TaskCompletion[];
  rewards: Reward[];
  claims: RewardClaim[];
  transactions: PointTransaction[];
  /** Wishlist domain — separate from points/rewards. */
  wishlistItems: WishlistItem[];
  /** HMAC token from openKidsSession for kid-path callables. */
  kidsAccessToken: string | null;
  /** family.settings.enableWishlist === true (missing = false). */
  wishlistEnabled: boolean;
  entitlements: Entitlements;
  parentEmail: string | null;
  kidsMode: boolean;
  setKidsMode: (on: boolean) => void;
  reset: () => void;
  /** Persist archive/restore to Firestore; optimistic UI, throws on failure. */
  setRewardActive: (id: string, isActive: boolean) => Promise<void>;
  /** Persist hard delete to Firestore; optimistic UI, throws on failure. */
  removeReward: (id: string) => Promise<void>;
  addReward: (input: {
    name: string;
    description: string;
    icon: string;
    pointCost: number;
    eligibleChildIds: string[];
    requiresApproval?: boolean;
  }) => Promise<Reward>;
  updateReward: (
    id: string,
    input: {
      name: string;
      description: string;
      icon: string;
      pointCost: number;
      eligibleChildIds: string[];
      requiresApproval: boolean;
    }
  ) => Promise<void>;
  /** Persist enableWishlist to Firestore families.settings + reload family. */
  setEnableWishlist: (enabled: boolean) => Promise<void>;
  addWishlistItem: (input: {
    childId: string;
    title: string;
    message?: string;
    occasion?: string | null;
  }) => Promise<WishlistItem>;
  updateWishlistItem: (input: {
    itemId: string;
    title: string;
    message?: string;
    occasion?: string | null;
    version?: number;
  }) => Promise<void>;
  deleteWishlistItem: (itemId: string) => Promise<void>;
  /** Parent only — APPROVED | REJECTED. Never touches points. */
  reviewWishlistItem: (input: {
    itemId: string;
    decision: Extract<WishlistStatus, "APPROVED" | "REJECTED">;
    parentResponse?: string | null;
    version?: number;
  }) => Promise<void>;
  addTask: (input: {
    name: string;
    description: string;
    icon: string;
    category: string;
    pointValue: number;
    approvalBehavior: TaskApprovalBehavior;
    assignedChildIds: string[];
    recurrence: TaskRecurrenceType;
  }) => Promise<KiddoTask>;
  updateTask: (
    id: string,
    input: {
      name: string;
      description: string;
      icon: string;
      category: string;
      pointValue: number;
      approvalBehavior: TaskApprovalBehavior;
      assignedChildIds: string[];
      recurrence: TaskRecurrenceType;
    }
  ) => Promise<void>;
  setTaskActive: (id: string, isActive: boolean) => Promise<void>;
  loadFamilyForParent: (uid: string) => Promise<void>;
  loadKidsSession: (payload: {
    family: Family;
    children: Child[];
    tasks: KiddoTask[];
    completions: TaskCompletion[];
    rewards: Reward[];
    claims: RewardClaim[];
    transactions: PointTransaction[];
    wishlistItems?: WishlistItem[];
    kidsAccessToken?: string | null;
    wishlistEnabled?: boolean;
  }) => void;
};

const emptyEntitlements: Entitlements = {
  plan: "free",
  status: "none",
};

export const useFamilyStore = create<FamilyState>((set, get) => ({
  loading: false,
  error: null,
  family: null,
  parentUid: null,
  children: [],
  tasks: [],
  completions: [],
  rewards: [],
  claims: [],
  transactions: [],
  wishlistItems: [],
  kidsAccessToken: null,
  wishlistEnabled: false,
  entitlements: emptyEntitlements,
  parentEmail: null,
  kidsMode: false,

  setKidsMode: (on) => set({ kidsMode: on }),

  setRewardActive: async (id, isActive) => {
    const previous = get().rewards;
    set({ rewards: previous.map((r) => (r.id === id ? { ...r, isActive } : r)) });
    try {
      if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
      const db = firestore();
      await updateDoc(doc(db, "rewards", id), {
        isActive,
        updatedAt: new Date().toISOString(),
      });
    } catch (e) {
      set({ rewards: previous });
      throw new Error(errorMessage(e, "Failed to update reward"));
    }
  },

  removeReward: async (id) => {
    const previous = get().rewards;
    const familyId = get().family?.id;
    if (!previous.some((r) => r.id === id)) {
      throw new Error("Couldn’t find that reward.");
    }
    set({ rewards: previous.filter((r) => r.id !== id) });
    try {
      if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
      const db = firestore();
      await deleteDoc(doc(db, "rewards", id));
      // Tombstone so iOS pushFamilySnapshot cannot re-upsert a deleted reward.
      if (familyId) {
        await setDoc(doc(db, "familyTombstones", `${familyId}:rewards:${id}`), {
          familyId,
          collectionName: "rewards",
          docId: id,
          deletedAt: new Date().toISOString(),
        });
      }
    } catch (e) {
      set({ rewards: previous });
      throw new Error(errorMessage(e, "Failed to delete reward"));
    }
  },

  addReward: async (input) => {
    const { family, parentUid } = get();
    if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
    if (!family || !parentUid) throw new Error("Sign in as a parent first.");
    const name = input.name.trim();
    if (!name) throw new Error("Reward name is required.");
    const pointCost = Math.max(1, Math.round(input.pointCost));
    const now = new Date().toISOString();
    const id = crypto.randomUUID();
    const reward: Reward = {
      id,
      familyId: family.id,
      name,
      description: input.description.trim(),
      icon: input.icon || "gift.fill",
      pointCost,
      eligibleChildIds: input.eligibleChildIds,
      requiresApproval: input.requiresApproval ?? true,
      isActive: true,
      createdBy: parentUid,
      createdAt: now,
      updatedAt: now,
      version: 1,
    };
    const previous = get().rewards;
    set({ rewards: [...previous, reward] });
    try {
      const db = firestore();
      await setDoc(doc(db, "rewards", id), reward);
      return reward;
    } catch (e) {
      set({ rewards: previous });
      throw new Error(errorMessage(e, "Failed to add reward"));
    }
  },

  updateReward: async (id, input) => {
    const previous = get().rewards;
    const existing = previous.find((r) => r.id === id);
    if (!existing) throw new Error("Couldn’t find that reward.");
    const name = input.name.trim();
    if (!name) throw new Error("Reward name is required.");
    const pointCost = Math.max(1, Math.round(input.pointCost));
    const next: Reward = {
      ...existing,
      name,
      description: input.description.trim(),
      icon: input.icon || existing.icon || "gift.fill",
      pointCost,
      eligibleChildIds: input.eligibleChildIds,
      requiresApproval: input.requiresApproval,
      updatedAt: new Date().toISOString(),
      version: (existing.version ?? 1) + 1,
    };
    set({ rewards: previous.map((r) => (r.id === id ? next : r)) });
    try {
      if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
      const db = firestore();
      // Only fields allowed by firestore.rules reward update.
      await updateDoc(doc(db, "rewards", id), {
        name: next.name,
        description: next.description,
        icon: next.icon,
        pointCost: next.pointCost,
        eligibleChildIds: next.eligibleChildIds,
        requiresApproval: next.requiresApproval,
        updatedAt: next.updatedAt,
        version: next.version,
      });
    } catch (e) {
      set({ rewards: previous });
      throw new Error(errorMessage(e, "Failed to update reward"));
    }
  },

  setEnableWishlist: async (enabled) => {
    const { family, parentUid } = get();
    if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
    if (!family || !parentUid) throw new Error("Sign in as a parent first.");
    const previous = family;
    const nextSettings = {
      ...(family.settings ?? {}),
      enableWishlist: enabled,
    };
    set({
      family: { ...family, settings: nextSettings },
      wishlistEnabled: enabled === true,
    });
    try {
      const db = firestore();
      // firestore.rules families update allows hasOnly(['name','settings','updatedAt']).
      await updateDoc(doc(db, "families", family.id), {
        settings: nextSettings,
        updatedAt: new Date().toISOString(),
      });
      await get().loadFamilyForParent(parentUid);
    } catch (e) {
      set({
        family: previous,
        wishlistEnabled: isWishlistEnabled(previous),
      });
      throw new Error(
        errorMessage(e, enabled ? "Couldn’t enable wishlist" : "Couldn’t disable wishlist")
      );
    }
  },

  addWishlistItem: async (input) => {
    const { family, parentUid, kidsAccessToken, kidsMode } = get();
    if (!family) throw new Error("Family not loaded.");
    const title = input.title.trim();
    if (!title) throw new Error("Item name is required.");
    const childId = input.childId?.trim();
    if (!childId) throw new Error("Select a child first.");
    const message = (input.message ?? "").trim();
    // Kid UI does not collect occasion; keep null unless caller sets it.
    const occasion = input.occasion || null;
    const payload: Record<string, unknown> = {
      familyId: family.id,
      childId,
      title,
      message,
      occasion,
    };
    // Prefer parent Firebase Auth when available; otherwise kid session token.
    if (parentUid && !kidsMode) {
      // Parent Auth via httpsCallable — no extra token.
    } else {
      if (!kidsAccessToken) {
        throw new Error(
          "Unlock Kids Station with the family PIN to add wishlist items."
        );
      }
      payload.kidsAccessToken = kidsAccessToken;
      payload.childId = childId;
    }
    try {
      const data = await callWishlistFn("addWishlistItem", payload);
      const id = String(data.id ?? crypto.randomUUID());
      const item: WishlistItem = {
        id,
        familyId: family.id,
        childId,
        title,
        message,
        occasion,
        status: "PENDING",
        parentResponse: null,
        createdBy: parentUid || "kids-session",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reviewedAt: null,
        reviewedBy: null,
        version: 1,
      };
      set({ wishlistItems: [...get().wishlistItems, item] });
      return item;
    } catch (e) {
      throw new Error(errorMessage(e, "Couldn’t add wishlist item"));
    }
  },

  updateWishlistItem: async (input) => {
    const { family, parentUid, kidsAccessToken, wishlistItems } = get();
    if (!family) throw new Error("Family not loaded.");
    const title = input.title.trim();
    if (!title) throw new Error("Item name is required.");
    const existing = wishlistItems.find((w) => w.id === input.itemId);
    const message = (input.message ?? "").trim();
    const occasion = input.occasion || null;
    const payload: Record<string, unknown> = {
      familyId: family.id,
      itemId: input.itemId,
      title,
      message,
      occasion,
    };
    if (input.version != null) payload.version = input.version;
    else if (existing?.version != null) payload.version = existing.version;
    if (!parentUid) {
      if (!kidsAccessToken) {
        throw new Error("Unlock Kids Station to update your wishlist.");
      }
      payload.kidsAccessToken = kidsAccessToken;
      if (existing?.childId) payload.childId = existing.childId;
    }
    try {
      await callWishlistFn("updateWishlistItem", payload);
      set({
        wishlistItems: wishlistItems.map((w) =>
          w.id === input.itemId
            ? {
                ...w,
                title,
                message,
                occasion,
                updatedAt: new Date().toISOString(),
                version: (w.version ?? 1) + 1,
              }
            : w
        ),
      });
    } catch (e) {
      throw new Error(errorMessage(e, "Couldn’t update wishlist item"));
    }
  },

  deleteWishlistItem: async (itemId) => {
    const { family, parentUid, kidsAccessToken, wishlistItems } = get();
    if (!family) throw new Error("Family not loaded.");
    const existing = wishlistItems.find((w) => w.id === itemId);
    const previous = wishlistItems;
    const payload: Record<string, unknown> = {
      familyId: family.id,
      itemId,
    };
    if (!parentUid) {
      if (!kidsAccessToken) {
        throw new Error("Unlock Kids Station to update your wishlist.");
      }
      payload.kidsAccessToken = kidsAccessToken;
      if (existing?.childId) payload.childId = existing.childId;
    }
    set({ wishlistItems: previous.filter((w) => w.id !== itemId) });
    try {
      await callWishlistFn("deleteWishlistItem", payload);
    } catch (e) {
      set({ wishlistItems: previous });
      throw new Error(errorMessage(e, "Couldn’t delete wishlist item"));
    }
  },

  reviewWishlistItem: async (input) => {
    const { family, parentUid, wishlistItems } = get();
    if (!family || !parentUid) throw new Error("Sign in as a parent first.");
    const existing = wishlistItems.find((w) => w.id === input.itemId);
    const parentResponse =
      input.parentResponse != null && String(input.parentResponse).trim()
        ? String(input.parentResponse).trim()
        : null;
    const payload: Record<string, unknown> = {
      familyId: family.id,
      itemId: input.itemId,
      decision: input.decision,
      parentResponse,
    };
    if (input.version != null) payload.version = input.version;
    else if (existing?.version != null) payload.version = existing.version;
    // Parent only — Firebase Auth; do not send kidsAccessToken.
    try {
      await callWishlistFn("reviewWishlistItem", payload);
      set({
        wishlistItems: wishlistItems.map((w) =>
          w.id === input.itemId
            ? {
                ...w,
                status: input.decision,
                parentResponse,
                reviewedAt: new Date().toISOString(),
                reviewedBy: parentUid,
                updatedAt: new Date().toISOString(),
                version: (w.version ?? 1) + 1,
              }
            : w
        ),
      });
    } catch (e) {
      throw new Error(errorMessage(e, "Couldn’t review wishlist item"));
    }
  },

  addTask: async (input) => {
    const { family, parentUid, parentEmail, entitlements, tasks } = get();
    if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
    if (!family || !parentUid) throw new Error("Sign in as a parent first.");
    const premium = entitlements.plan === "plus" || entitlements.plan === "pro";
    if (!canAddTask(tasks.length, parentEmail, premium)) {
      throw new Error("Free plan includes up to 20 chores. Upgrade to add more.");
    }
    const name = input.name.trim();
    if (!name) throw new Error("Chore name is required.");
    const pointValue = Math.max(1, Math.round(input.pointValue));
    const requiresApproval = requiresApprovalFromBehavior(
      input.approvalBehavior,
      Boolean(family.settings?.requireApprovalByDefault)
    );
    const now = new Date().toISOString();
    const id = crypto.randomUUID();
    const task: KiddoTask = {
      id,
      familyId: family.id,
      name,
      description: input.description.trim(),
      icon: input.icon || "checkmark.circle",
      category: input.category || "household",
      pointValue,
      requiresApproval,
      approvalBehavior: input.approvalBehavior,
      assignedChildIds: input.assignedChildIds,
      recurrence: { type: input.recurrence },
      isActive: true,
      createdBy: parentUid,
      createdAt: now,
      updatedAt: now,
      version: 1,
    };
    const previous = get().tasks;
    set({ tasks: [...previous, task] });
    try {
      const db = firestore();
      await setDoc(doc(db, "tasks", id), task);
      return task;
    } catch (e) {
      set({ tasks: previous });
      throw new Error(errorMessage(e, "Failed to add chore"));
    }
  },

  updateTask: async (id, input) => {
    const previous = get().tasks;
    const { family } = get();
    const existing = previous.find((t) => t.id === id);
    if (!existing) throw new Error("Couldn’t find that chore.");
    const name = input.name.trim();
    if (!name) throw new Error("Chore name is required.");
    const pointValue = Math.max(1, Math.round(input.pointValue));
    const requiresApproval = requiresApprovalFromBehavior(
      input.approvalBehavior,
      Boolean(family?.settings?.requireApprovalByDefault)
    );
    const next: KiddoTask = {
      ...existing,
      name,
      description: input.description.trim(),
      icon: input.icon || existing.icon || "checkmark.circle",
      category: input.category || existing.category || "household",
      pointValue,
      requiresApproval,
      approvalBehavior: input.approvalBehavior,
      assignedChildIds: input.assignedChildIds,
      recurrence: {
        type: input.recurrence,
        weekdays: existing.recurrence?.weekdays,
      },
      updatedAt: new Date().toISOString(),
      version: (existing.version ?? 1) + 1,
    };
    set({ tasks: previous.map((t) => (t.id === id ? next : t)) });
    try {
      if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
      const db = firestore();
      await updateDoc(doc(db, "tasks", id), {
        name: next.name,
        description: next.description,
        icon: next.icon,
        category: next.category,
        pointValue: next.pointValue,
        requiresApproval: next.requiresApproval,
        approvalBehavior: next.approvalBehavior,
        assignedChildIds: next.assignedChildIds,
        recurrence: next.recurrence,
        updatedAt: next.updatedAt,
        version: next.version,
      });
    } catch (e) {
      set({ tasks: previous });
      throw new Error(errorMessage(e, "Failed to update chore"));
    }
  },

  setTaskActive: async (id, isActive) => {
    const previous = get().tasks;
    set({ tasks: previous.map((t) => (t.id === id ? { ...t, isActive } : t)) });
    try {
      if (!isFirebaseConfigured) throw new Error("Firebase is not configured.");
      const db = firestore();
      await updateDoc(doc(db, "tasks", id), {
        isActive,
        updatedAt: new Date().toISOString(),
      });
    } catch (e) {
      set({ tasks: previous });
      throw new Error(errorMessage(e, "Failed to update chore"));
    }
  },

  reset: () =>
    set({
      loading: false,
      error: null,
      family: null,
      parentUid: null,
      parentEmail: null,
      children: [],
      tasks: [],
      completions: [],
      rewards: [],
      claims: [],
      transactions: [],
      wishlistItems: [],
      kidsAccessToken: null,
      wishlistEnabled: false,
      entitlements: emptyEntitlements,
      kidsMode: false,
    }),

  loadKidsSession: (payload) => {
    const {
      wishlistItems = [],
      kidsAccessToken = null,
      wishlistEnabled = false,
      ...rest
    } = payload;
    set({
      loading: false,
      error: null,
      parentUid: null,
      parentEmail: null,
      kidsMode: true,
      ...rest,
      wishlistItems: Array.isArray(wishlistItems)
        ? wishlistItems.map((w) =>
            mapWishlistDoc(String(w.id ?? ""), w as unknown as Record<string, unknown>)
          )
        : [],
      kidsAccessToken: kidsAccessToken || null,
      wishlistEnabled: wishlistEnabled === true,
    });
  },

  loadFamilyForParent: async (uid) => {
    if (!isFirebaseConfigured) {
      set({ error: "Firebase is not configured (check .env.local)." });
      return;
    }
    set({ loading: true, error: null, parentUid: uid, kidsMode: false });
    try {
      const db = firestore();
      const parentSnap = await getDoc(doc(db, "parents", uid));
      if (!parentSnap.exists()) {
        set({ loading: false, family: null, error: "No family for this account." });
        return;
      }
      const parentEmail = (parentSnap.data()?.email as string) ?? null;
      const familyId = parentSnap.data()?.familyId as string;
      const familySnap = await getDoc(doc(db, "families", familyId));
      if (!familySnap.exists()) {
        set({ loading: false, family: null, error: "Family not found." });
        return;
      }
      const family = { id: familySnap.id, ...(familySnap.data() as Omit<Family, "id">) };
      const plan = (family.settings?.plan as string) || "free";
      const entitlements: Entitlements = {
        plan: plan === "plus" || plan === "pro" ? (plan as Entitlements["plan"]) : "free",
        status: plan === "free" ? "none" : "active",
      };

      const load = async <T extends { id: string }>(name: string): Promise<T[]> => {
        const snap = await getDocs(
          query(collection(db, name), where("familyId", "==", familyId))
        );
        return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as T);
      };

      // Core family data must load even if optional collections are denied
      // (e.g. wishlistItems before firestore.rules are redeployed).
      const loadSafe = async <T extends { id: string }>(
        name: string,
        map?: (id: string, data: Record<string, unknown>) => T
      ): Promise<{ rows: T[]; denied?: boolean }> => {
        try {
          const snap = await getDocs(
            query(collection(db, name), where("familyId", "==", familyId))
          );
          const rows = snap.docs.map((d) =>
            map
              ? map(d.id, d.data() as Record<string, unknown>)
              : ({ id: d.id, ...d.data() } as T)
          );
          return { rows };
        } catch (e) {
          const msg = errorMessage(e, "");
          if (/permission/i.test(msg)) return { rows: [], denied: true };
          throw e;
        }
      };

      const [children, tasks, completions, rewards, claims, transactions, wishlistLoad] =
        await Promise.all([
          load<Child>("children"),
          load<KiddoTask>("tasks"),
          load<TaskCompletion>("taskCompletions"),
          load<Reward>("rewards"),
          load<RewardClaim>("rewardClaims"),
          load<PointTransaction>("pointTransactions"),
          loadSafe<WishlistItem>("wishlistItems", mapWishlistDoc),
        ]);

      const wishlistItems = wishlistLoad.rows;

      set({
        loading: false,
        family,
        parentEmail,
        children,
        tasks,
        completions,
        rewards,
        claims,
        transactions,
        wishlistItems,
        kidsAccessToken: null,
        wishlistEnabled: isWishlistEnabled(family),
        entitlements,
        error: null,
      });
      if (wishlistLoad.denied) {
        console.warn(
          "[wishlist] parent read denied for wishlistItems — deploy firestore.rules so parents can list wishlist. Family data loaded."
        );
      }
    } catch (e) {
      set({
        loading: false,
        error: errorMessage(e, "Failed to load family"),
      });
    }
  },
}));

export function useEntitlements() {
  const entitlements = useFamilyStore((s) => s.entitlements);
  const parentEmail = useFamilyStore((s) => s.parentEmail);
  const isOwner = isOwnerEmail(parentEmail);
  return {
    ...entitlements,
    isOwner,
    isPlus: isOwner || entitlements.plan === "plus" || entitlements.plan === "pro",
    isPro: isOwner || entitlements.plan === "pro",
  };
}
