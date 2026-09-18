import type { TaskApprovalBehavior, TaskCategory, TaskRecurrenceType } from "./types";

export const TASK_CATEGORIES: { id: TaskCategory; label: string }[] = [
  { id: "household", label: "Household" },
  { id: "learning", label: "Learning" },
  { id: "health", label: "Health" },
  { id: "personal", label: "Personal care" },
  { id: "pets", label: "Pet care" },
  { id: "other", label: "Other" },
];

export const TASK_APPROVAL_OPTIONS: { id: TaskApprovalBehavior; label: string }[] = [
  { id: "useFamilyDefault", label: "Use family setting" },
  { id: "alwaysRequireApproval", label: "Always require approval" },
  { id: "autoApprove", label: "Auto-approve and award points" },
];

export const TASK_RECURRENCE_OPTIONS: { id: TaskRecurrenceType; label: string }[] = [
  { id: "oneTime", label: "One time" },
  { id: "daily", label: "Every day" },
  { id: "weekdays", label: "Weekdays" },
  { id: "weekly", label: "Weekly" },
  { id: "custom", label: "Custom" },
];

/** SF Symbol names shared with the iOS icon picker. */
export const TASK_ICONS = [
  "checkmark.circle",
  "bed.double",
  "fork.knife",
  "trash",
  "washer",
  "shower",
  "book",
  "pencil",
  "figure.run",
  "leaf",
  "paw",
  "broom",
  "paintbrush",
  "basketball",
  "gamecontroller",
] as const;

export const REWARD_ICONS = [
  "gift.fill",
  "star.fill",
  "crown.fill",
  "party.popper",
  "film",
  "gamecontroller",
  "icecream",
  "cart.fill",
  "ticket",
  "sparkles",
] as const;

export function requiresApprovalFromBehavior(
  behavior: TaskApprovalBehavior,
  familyDefault: boolean
): boolean {
  if (behavior === "alwaysRequireApproval") return true;
  if (behavior === "autoApprove") return false;
  return familyDefault;
}
