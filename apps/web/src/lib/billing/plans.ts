/** Server-side plan catalog. Browser never sends amounts. */
export const PLAN_IDS = {
  premium_monthly: "premium_monthly",
} as const;

export type PlanId = keyof typeof PLAN_IDS;

export type PlanDefinition = {
  id: PlanId;
  name: string;
  /** Centavos (PayMongo integer amounts). ₱199.00 = 19900 */
  amount: number;
  currency: "PHP";
  interval: "month";
  intervalCount: number;
  display: string;
  billingNote: string;
};

export const PLANS: Record<PlanId, PlanDefinition> = {
  premium_monthly: {
    id: "premium_monthly",
    name: "KiddoTasks Premium",
    amount: 19900,
    currency: "PHP",
    interval: "month",
    intervalCount: 1,
    display: "₱199/month",
    billingNote: "₱199/month. Recurring subscription. Cancel anytime.",
  },
};

export function resolvePlan(planId: string | null | undefined): PlanDefinition | null {
  if (!planId) return null;
  return PLANS[planId as PlanId] ?? null;
}

/** Configurable upsell copy (single source for billing UI). */
export const PREMIUM_BENEFITS = [
  "Unlimited kids & chores",
  "Co-parent join with family code",
  "Full history",
  "Allowance modes (flat daily / per chore)",
  "Week bonus celebrations",
  "Priority support",
  "Future Premium features",
] as const;
