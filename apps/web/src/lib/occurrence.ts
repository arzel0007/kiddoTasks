import { requiresApprovalFromBehavior } from "./catalog";
import type { KiddoTask, TaskCompletion } from "./types";

/**
 * Web mirror of `Firebase/functions/src/occurrence.ts`.
 *
 * The Kids Station card must reach the exact same verdict as the server's
 * duplicate guard, otherwise the button state and what the server will accept
 * drift apart across devices. Keep this file in lockstep with:
 *   - Firebase/functions/src/occurrence.ts  (authoritative)
 *   - Kiddotasks/Services/CompletionEligibility.swift
 *
 * Rules:
 *  1. `oneTime` missions are blocked forever by ANY non-rejected completion.
 *  2. Recurring missions are blocked only for the SAME occurrence —
 *     `D:YYYY-MM-DD` for daily/weekdays/custom, `W:YYYY-Www` for weekly.
 *  3. A completion still waiting for a parent always blocks its occurrence.
 *  4. Once a parent has decided an approval-gated recurring mission it reopens.
 *  5. Auto-approved recurring missions stay locked for the occurrence.
 *  6. REJECTED never blocks anything.
 */

const PENDING_STATUSES = new Set(["AWAITING_APPROVAL", "COMPLETED"]);
const DAY_MS = 24 * 60 * 60 * 1000;

/** The browser's IANA zone — sent to the server so both derive the same day. */
export function deviceTimeZone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  } catch {
    return "UTC";
  }
}

/** Accepts an ISO string or a Firestore Timestamp. */
function toDate(value: unknown): Date | null {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
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

/** ISO-8601 week of a proleptic-Gregorian calendar date → `YYYY-Www`. */
export function isoWeekKey(year: number, month: number, day: number): string {
  const target = new Date(Date.UTC(year, month - 1, day));
  const weekday = (target.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - weekday + 3);
  const isoYear = target.getUTCFullYear();

  const firstThursday = new Date(Date.UTC(isoYear, 0, 4));
  const firstWeekday = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstWeekday + 3);

  const week = 1 + Math.round((target.getTime() - firstThursday.getTime()) / (7 * DAY_MS));
  return `${isoYear}-W${week < 10 ? `0${week}` : String(week)}`;
}

/** `null` for `oneTime`, which is never occurrence-scoped. */
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

export function taskRecurrenceType(task: KiddoTask): string {
  return task.recurrence?.type ?? "oneTime";
}

export function taskRequiresApproval(task: KiddoTask, familyDefault: boolean): boolean {
  return requiresApprovalFromBehavior(
    (task.approvalBehavior ?? "useFamilyDefault") as Parameters<
      typeof requiresApprovalFromBehavior
    >[0],
    familyDefault
  );
}

/** The completion's occurrence, falling back to `completedAt` for legacy rows. */
function completionOccurrenceKey(
  completion: TaskCompletion,
  recurrenceType: string,
  timeZone: string
): string | null {
  if (recurrenceType === "oneTime") return null;
  if (completion.occurrenceKey) return completion.occurrenceKey;
  const at = toDate(completion.completedAt);
  return at ? computeOccurrenceKey(recurrenceType, at, timeZone) : null;
}

export interface OccurrenceQuery {
  task: KiddoTask;
  completions: TaskCompletion[];
  childId: string;
  now: Date;
  timeZone: string;
  /** `family.settings.requireApprovalByDefault !== false`, matching the server. */
  familyDefault: boolean;
}

/** Non-rejected completions for this task/child that belong to the current occurrence. */
function occurrenceCandidates(query: OccurrenceQuery): TaskCompletion[] {
  const { task, completions, childId, now, timeZone } = query;
  const recurrenceType = taskRecurrenceType(task);
  const notRejected = completions.filter(
    (completion) =>
      completion.taskId === task.id &&
      completion.childId === childId &&
      completion.status !== "REJECTED"
  );

  // One-time missions are occurrence-independent — every past run counts.
  if (recurrenceType === "oneTime") return notRejected;

  const currentKey = computeOccurrenceKey(recurrenceType, now, timeZone);
  if (!currentKey) return [];
  return notRejected.filter((completion) => {
    const key = completionOccurrenceKey(completion, recurrenceType, timeZone);
    // An unresolvable legacy row is treated as matching (fail closed).
    return key === null || key === currentKey;
  });
}

/**
 * The completion the card should display for the current occurrence.
 * `null` means "show no status / show Ready".
 */
export function latestOccurrenceCompletion(query: OccurrenceQuery): TaskCompletion | null {
  const candidates = occurrenceCandidates(query);
  return candidates.length > 0 ? candidates[candidates.length - 1] : null;
}

/**
 * The completion that stops the child submitting again, or `null` when the
 * "I did it!" button must stay enabled. Must equal the server's verdict.
 */
export function findBlockingCompletion(query: OccurrenceQuery): TaskCompletion | null {
  const { task, completions, childId, now, timeZone, familyDefault } = query;
  const recurrenceType = taskRecurrenceType(task);

  // Rule 1 — one-time missions never come back.
  if (recurrenceType === "oneTime") {
    const done = completions.find(
      (completion) =>
        completion.taskId === task.id &&
        completion.childId === childId &&
        completion.status !== "REJECTED"
    );
    return done ?? null;
  }

  const sameOccurrence = occurrenceCandidates(query);
  if (sameOccurrence.length === 0) return null;

  // Rule 3 — the parent has not decided yet.
  const pending = sameOccurrence.filter((completion) =>
    PENDING_STATUSES.has(completion.status)
  );
  if (pending.length > 0) return pending[0];

  // Rule 5 — auto-approved missions are once per occurrence.
  if (!taskRequiresApproval(task, familyDefault)) return sameOccurrence[0];

  // Rule 4 — the parent already approved → reopen.
  return null;
}

