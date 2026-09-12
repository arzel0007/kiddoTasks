"use client";

import { create } from "zustand";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
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
} from "./types";
import { isOwnerEmail } from "./entitlements";

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

export const useFamilyStore = create<FamilyState>((set) => ({
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
