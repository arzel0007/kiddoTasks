/**
 * Recurrence-aware completion eligibility.
 *
 * This module is the authoritative copy of the duplicate rule. Two sibling
 * implementations mirror it exactly so phone, iPad and web can never disagree:
 *   - web  → apps/web/src/lib/occurrence.ts
 *   - iOS  → Kiddotasks/Services/CompletionEligibility.swift
 *
 * Rules:
 *  1. `oneTime` missions are blocked forever by ANY non-rejected completion.
 *  2. Recurring missions (daily / weekdays / weekly / custom) are blocked only
 *     for the SAME occurrence — `D:YYYY-MM-DD` for daily-style recurrence and
 *     `W:YYYY-Www` (ISO week) for weekly. Yesterday's completion never blocks
 *     today, and last week's completion never blocks this week.
 *  3. A completion still waiting for a parent (AWAITING_APPROVAL / COMPLETED)
 *     always blocks its occurrence.
 *  4. Once a parent has DECIDED an approval-gated recurring mission (approved
 *     or rejected) the mission reopens — these chores may be done more than
 *     once a day, and the parent is the throttle.
 *  5. Auto-approved recurring missions stay locked for the occurrence after
 *     approval, because no parent sits in the loop and otherwise points could
 *     be farmed by submitting over and over.
 *  6. REJECTED never blocks anything.
 *
 * NOTE: the server writes `occurrenceKey` on every new completion. Rows
 * created before this field existed fall back to deriving the key from their
 * `completedAt`, so historical data keeps working.
 */

export type RecurrenceType = "oneTime" | "daily" | "weekdays" | "weekly" | "custom";

/** Loose shape of a `taskCompletions` document. */
export interface CompletionLike {
  status?: unknown;
  completedAt?: unknown;
  occurrenceKey?: unknown;
}

const REJECTED_STATUS = "REJECTED";
const PENDING_STATUSES = new Set(["AWAITING_APPROVAL", "COMPLETED"]);
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Validates an IANA time zone supplied by a client and falls back to UTC.
 * A bogus zone must never be able to bypass the duplicate guard.
 */
export function normalizeTimeZone(timeZone: unknown): string {
  const value = typeof timeZone === "string" ? timeZone.trim() : "";
  if (!value) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format(new Date(0));
    return value;
  } catch {
    return "UTC";
  }
}

/**
 * Resolves whether a mission needs a parent sign-off.
 * `approvalBehavior` is the canonical field; the legacy `requiresApproval`
 * boolean (written pre-computed by older clients) wins over the family
 * default so existing tasks keep their current behaviour.
 */
export function resolveRequiresApproval(
  task: { requiresApproval?: unknown; approvalBehavior?: unknown },
  familyDefault: boolean
): boolean {
  const behavior = String(task.approvalBehavior || "");
  if (behavior === "alwaysRequireApproval") return true;
  if (behavior === "autoApprove") return false;
  if (typeof task.requiresApproval === "boolean") return task.requiresApproval;
  return familyDefault;
}

/** Accepts a Date, an ISO string/number, or a Firestore Timestamp. */
function toDate(value: unknown): Date | null {
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof (value as { toDate?: unknown }).toDate === "function") {
    const parsed = (value as { toDate: () => unknown }).toDate();
    if (parsed instanceof Date) return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

/** `YYYY-MM-DD` for the instant, read in the family's time zone. */
function formatYmd(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const pick = (type: string) => {
    const found = parts.find((part) => part.type === type);
    return found ? found.value : "";
  };
  return `${pick("year")}-${pick("month")}-${pick("day")}`;
}

/**
 * ISO-8601 week of a proleptic-Gregorian calendar date → `YYYY-Www`.
 * A weekly mission occurs once per ISO week, not once per calendar day.
 */
export function isoWeekKey(year: number, month: number, day: number): string {
  const target = new Date(Date.UTC(year, month - 1, day));
  const weekday = (target.getUTCDay() + 6) % 7; // Monday = 0 … Sunday = 6
  // The Thursday of this ISO week decides which year the week belongs to.
  target.setUTCDate(target.getUTCDate() - weekday + 3);
  const isoYear = target.getUTCFullYear();

  const firstThursday = new Date(Date.UTC(isoYear, 0, 4));
  const firstWeekday = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstWeekday + 3);

  const week = 1 + Math.round((target.getTime() - firstThursday.getTime()) / (7 * DAY_MS));
  return `${isoYear}-W${week < 10 ? `0${week}` : String(week)}`;
}

/**
 * Server-authoritative occurrence key for an instant.
 * Returns `null` for `oneTime` missions, which are never occurrence-scoped.
 */
export function computeOccurrenceKey(
  recurrenceType: string,
  at: Date,
  timeZone: string
): string | null {
  if (recurrenceType === "oneTime") return null;
  const ymd = formatYmd(at, timeZone);
  if (recurrenceType === "weekly") {
    const [year, month, day] = ymd.split("-").map((part) => parseInt(part, 10));
    return `W:${isoWeekKey(year, month, day)}`;
  }
  return `D:${ymd}`;
}

/**
 * Occurrence key of an already-stored completion.
 * Legacy rows without `occurrenceKey` derive it from `completedAt`.
 * `null` means "cannot be resolved" and callers treat it as always-matching,
 * so a malformed historical row can never be used to farm points.
 */
export function completionOccurrenceKey(
  completion: CompletionLike,
  recurrenceType: string,
  timeZone: string
): string | null {
  if (recurrenceType === "oneTime") return null;
  if (typeof completion.occurrenceKey === "string" && completion.occurrenceKey.length > 0) {
    return completion.occurrenceKey;
  }
  const at = toDate(completion.completedAt);
  return at ? computeOccurrenceKey(recurrenceType, at, timeZone) : null;
}

export interface BlockingOptions {
  recurrenceType: string;
  requiresApproval: boolean;
  completions: CompletionLike[];
  /** The instant being submitted — usually the kid-reported `completedAt`. */
  now: Date;
  timeZone: string;
}

/**
 * Returns the completion that blocks this submission, or `null` when the
 * mission is eligible. `null` must mean "go ahead" on every platform.
 */
export function findBlockingCompletion(options: BlockingOptions): CompletionLike | null {
  const { recurrenceType, requiresApproval, completions, now, timeZone } = options;

  const notRejected = completions.filter(
    (completion) => String(completion.status || "").toUpperCase() !== REJECTED_STATUS
  );

  // Rule 1 — one-time missions never come back once they are done.
  if (recurrenceType === "oneTime") {
    return notRejected.length > 0 ? notRejected[0] : null;
  }

  const currentKey = computeOccurrenceKey(recurrenceType, now, timeZone);
  if (!currentKey) return null;

  // Rule 2 — only completions belonging to this occurrence count.
  const sameOccurrence = notRejected.filter((completion) => {
    const key = completionOccurrenceKey(completion, recurrenceType, timeZone);
    return key === null || key === currentKey;
  });
  if (sameOccurrence.length === 0) return null;

  // Rule 3 — a parent decision is still pending.
  const pending = sameOccurrence.filter((completion) =>
    PENDING_STATUSES.has(String(completion.status || "").toUpperCase())
  );
  if (pending.length > 0) return pending[0];

  // Rule 5 — auto-approved missions are once per occurrence.
  if (!requiresApproval) return sameOccurrence[0];

  // Rule 4 — the parent already approved this occurrence → reopen.
  return null;
}

