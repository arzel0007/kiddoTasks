import type { Entitlements } from "../types";
import { PREMIUM_PRICE, isOwnerEmail } from "../entitlements";
import { PLANS } from "./plans";

export type BillingSubscriptionStatus = {
  premium?: boolean;
  status?: string | null;
  currentPeriodEnd?: string | null;
  cancelAtPeriodEnd?: boolean;
} | null;

export type PlanDisplay = {
  isPremium: boolean;
  isOwner: boolean;
  title: string;
  subtitle: string;
  statusLabel: string;
  statusTone: "success" | "neutral";
  periodEnd: string | null;
  ownerNote: string | null;
  freeSummary: string;
  premiumPrice: string;
};

/**
 * Single source for plan copy on Plan tab + Family tab (and anywhere else).
 * Owner / Premium entitlement always wins over a missing billing snapshot.
 */
export function computePlanDisplay(
  ent: Entitlements & { isOwner?: boolean; isPlus?: boolean },
  parentEmail?: string | null,
  sub?: BillingSubscriptionStatus
): PlanDisplay {
  const isOwner = ent.isOwner === true || isOwnerEmail(parentEmail);
  const isPlus = ent.isPlus === true || ent.plan === "plus" || ent.plan === "pro";
  const isPremium = isOwner || isPlus || sub?.premium === true;

  const title = isPremium ? PLANS.premium_monthly.name : "KiddoTasks Free";
  const subtitle = isPremium
    ? PLANS.premium_monthly.display
    : "Upgrade to unlock Premium";

  const statusLabel = isOwner
    ? "Founder"
    : sub?.status === "active"
      ? "Active"
      : sub?.status === "past_due"
        ? "Past due"
        : sub?.status === "canceled"
          ? "Canceled"
          : isPremium
            ? "Active"
            : "Free";

  const rawEnd = sub?.currentPeriodEnd ?? ent.currentPeriodEnd ?? null;
  let periodEnd: string | null = null;
  if (rawEnd) {
    const d = new Date(rawEnd);
    if (!Number.isNaN(d.getTime())) {
      periodEnd = d.toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric",
      });
    }
  }

  return {
    isPremium,
    isOwner,
    title,
    subtitle,
    statusLabel,
    statusTone: isPremium ? "success" : "neutral",
    periodEnd,
    ownerNote: isOwner ? "Founder account — always Premium. No charge." : null,
    freeSummary: "Free: 1 kid · 20 chores · PIN Kids Station",
    premiumPrice: PREMIUM_PRICE.display,
  };
}
