/** Shared plan rules (mirrors iOS `KiddoPlan.swift`). */

export const OWNER_EMAILS = new Set(["xxarzelxx@gmail.com"]);

export const FREE_LIMITS = {
  maxChildren: 1,
  maxTasks: 20,
  historyDays: 7,
} as const;

export const PREMIUM_PRICE = {
  monthlyPHP: 199,
  display: "₱199/mo",
} as const;

export function isOwnerEmail(email?: string | null): boolean {
  if (!email) return false;
  return OWNER_EMAILS.has(email.trim().toLowerCase());
}

export function isPremiumFamily(entitlements: {
  plan: string;
  status?: string;
}): boolean {
  return entitlements.plan === "plus" || entitlements.plan === "pro";
}

/** Co-parent join with family code is Premium (owner exempt). */
export function canJoinWithCode(email: string | null | undefined, premium: boolean): boolean {
  return isOwnerEmail(email) || premium;
}

export function canAddChild(count: number, email: string | null | undefined, premium: boolean): boolean {
  if (isOwnerEmail(email) || premium) return true;
  return count < FREE_LIMITS.maxChildren;
}

export function canAddTask(count: number, email: string | null | undefined, premium: boolean): boolean {
  if (isOwnerEmail(email) || premium) return true;
  return count < FREE_LIMITS.maxTasks;
}

export type AllowanceMode = "STARS_ONLY" | "FLAT_DAILY" | "PER_CHORE";

export const ALLOWANCE_MODES: { id: AllowanceMode; label: string }[] = [
  { id: "STARS_ONLY", label: "Stars only" },
  { id: "FLAT_DAILY", label: "Flat daily rate" },
  { id: "PER_CHORE", label: "Per chore" },
];
