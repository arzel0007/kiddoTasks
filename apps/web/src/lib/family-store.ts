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
import { firestore, isFirebaseConfigured } from "./firebase";
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
} from "./types";
import { canAddTask, isOwnerEmail } from "./entitlements";
import { requiresApprovalFromBehavior } from "./catalog";

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
      throw e instanceof Error ? e : new Error("Failed to update reward");
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
      throw e instanceof Error ? e : new Error("Failed to delete reward");
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
      throw e instanceof Error ? e : new Error("Failed to add reward");
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
      throw e instanceof Error ? e : new Error("Failed to update reward");
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
      throw e instanceof Error ? e : new Error("Failed to add chore");
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
      throw e instanceof Error ? e : new Error("Failed to update chore");
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
      throw e instanceof Error ? e : new Error("Failed to update chore");
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
      entitlements: emptyEntitlements,
      kidsMode: false,
    }),

  loadKidsSession: (payload) =>
    set({
      loading: false,
      error: null,
      parentUid: null,
      parentEmail: null,
      kidsMode: true,
      ...payload,
    }),

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

      const [children, tasks, completions, rewards, claims, transactions] =
        await Promise.all([
          load<Child>("children"),
          load<KiddoTask>("tasks"),
          load<TaskCompletion>("taskCompletions"),
          load<Reward>("rewards"),
          load<RewardClaim>("rewardClaims"),
          load<PointTransaction>("pointTransactions"),
        ]);

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
        entitlements,
        error: null,
      });
    } catch (e) {
      set({
        loading: false,
        error: e instanceof Error ? e.message : "Failed to load family",
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
