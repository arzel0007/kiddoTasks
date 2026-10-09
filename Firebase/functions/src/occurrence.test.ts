import {
  CompletionLike,
  computeOccurrenceKey,
  findBlockingCompletion,
  isoWeekKey,
  normalizeTimeZone,
  resolveRequiresApproval,
} from "./occurrence";

const TZ = "Asia/Manila";
const day = (iso: string) => new Date(`${iso}T12:00:00.000Z`);

/** Mirrors what `submitTaskCompletion` asks before it writes a row. */
function blocked(
  completions: CompletionLike[],
  opts: {
    recurrence?: string;
    requiresApproval?: boolean;
    now: Date;
    timeZone?: string;
  }
): boolean {
  return (
    findBlockingCompletion({
      recurrenceType: opts.recurrence ?? "daily",
      requiresApproval: opts.requiresApproval ?? true,
      completions,
      now: opts.now,
      timeZone: opts.timeZone ?? TZ,
    }) !== null
  );
}

describe("occurrence keys", () => {
  it("keys daily-style recurrence by family-local date", () => {
    expect(computeOccurrenceKey("daily", day("2026-10-09"), TZ)).toBe("D:2026-10-09");
    expect(computeOccurrenceKey("weekdays", day("2026-10-09"), TZ)).toBe("D:2026-10-09");
    expect(computeOccurrenceKey("custom", day("2026-10-09"), TZ)).toBe("D:2026-10-09");
  });

  it("keys weekly recurrence by ISO week", () => {
    expect(isoWeekKey(2026, 10, 9)).toBe("2026-W41");
    expect(computeOccurrenceKey("weekly", day("2026-10-09"), TZ)).toBe("W:2026-W41");
    // Two Thursdays in the same ISO week share a key; the next week does not.
    expect(computeOccurrenceKey("weekly", day("2026-10-08"), TZ)).toBe("W:2026-W41");
    expect(computeOccurrenceKey("weekly", day("2026-10-15"), TZ)).toBe("W:2026-W42");
  });

  it("never scopes one-time missions to an occurrence", () => {
    expect(computeOccurrenceKey("oneTime", day("2026-10-09"), TZ)).toBeNull();
  });

  it("reads the day in the family time zone, not UTC", () => {
    // Manila (UTC+8) 2026-10-09 00:30 == UTC 2026-10-08 16:30.
    const manilaMidnight = new Date("2026-10-08T16:30:00.000Z");
    expect(computeOccurrenceKey("daily", manilaMidnight, "Asia/Manila")).toBe("D:2026-10-09");
    expect(computeOccurrenceKey("daily", manilaMidnight, "UTC")).toBe("D:2026-10-08");
  });

  it("rejects a bogus time zone instead of bypassing the guard", () => {
    expect(normalizeTimeZone("Not/AZone")).toBe("UTC");
    expect(normalizeTimeZone("Asia/Manila")).toBe("Asia/Manila");
    expect(normalizeTimeZone(undefined)).toBe("UTC");
  });
});

// ---------------------------------------------------------------------------
// The six required regression scenarios.
// ---------------------------------------------------------------------------

describe("regression: duplicate prevention", () => {
  const today = day("2026-10-09");

  it("1. same child, same task, same day across phone and web is blocked after the first submission", () => {
    const phoneSubmitted: CompletionLike[] = [
      { status: "AWAITING_APPROVAL", occurrenceKey: "D:2026-10-09" },
    ];
    expect(blocked(phoneSubmitted, { now: today })).toBe(true);
  });

  it("2. a daily task completed yesterday is available today", () => {
    // Auto-approved so only the occurrence key can explain the result.
    const yesterdayPending: CompletionLike[] = [
      { status: "AWAITING_APPROVAL", occurrenceKey: "D:2026-10-08" },
    ];
    expect(blocked(yesterdayPending, { now: today, requiresApproval: false })).toBe(false);
    // …but still blocked when the kid back-dates the submission to yesterday.
    expect(blocked(yesterdayPending, { now: day("2026-10-08"), requiresApproval: false })).toBe(
      true
    );

    const yesterdayApproved: CompletionLike[] = [
      { status: "APPROVED", occurrenceKey: "D:2026-10-08" },
    ];
    expect(blocked(yesterdayApproved, { now: today, requiresApproval: false })).toBe(false);
  });

  it("3. a weekly task completed last week is available this week", () => {
    const lastWeek: CompletionLike[] = [{ status: "APPROVED", occurrenceKey: "W:2026-W40" }];
    expect(blocked(lastWeek, { recurrence: "weekly", now: today, requiresApproval: false })).toBe(
      false
    );
    expect(
      blocked(lastWeek, { recurrence: "weekly", now: day("2026-10-02"), requiresApproval: false })
    ).toBe(true);
  });

  it("4. a one-time task completed in the past is unavailable forever", () => {
    const monthsAgo: CompletionLike[] = [{ status: "APPROVED", occurrenceKey: "D:2025-01-15" }];
    expect(blocked(monthsAgo, { recurrence: "oneTime", now: today })).toBe(true);
    // Even with no occurrence key at all, and even after approval.
    expect(blocked([{ status: "APPROVED" }], { recurrence: "oneTime", now: today })).toBe(true);
  });

  it("5. a rejected task is available again for the same occurrence", () => {
    expect(blocked([{ status: "REJECTED", occurrenceKey: "D:2026-10-09" }], { now: today })).toBe(
      false
    );
    expect(
      blocked([{ status: "REJECTED", occurrenceKey: "W:2026-W41" }], {
        recurrence: "weekly",
        now: today,
      })
    ).toBe(false);
    expect(blocked([{ status: "REJECTED" }], { recurrence: "oneTime", now: today })).toBe(false);
  });

  it("6. two devices submitting simultaneously produce exactly one completion", () => {
    // `submitTaskCompletion` reads the duplicate set and writes inside one
    // Firestore transaction, so concurrent calls are serialised: the loser
    // re-runs its read after the winner's write is visible. Model that by
    // having each attempt check-then-append against the shared array.
    const shared: CompletionLike[] = [];
    let pointsAwarded = 0;

    const attempt = () => {
      if (blocked(shared, { now: today })) return false;
      shared.push({ status: "AWAITING_APPROVAL", occurrenceKey: "D:2026-10-09" });
      pointsAwarded += 1;
      return true;
    };

    const results = [attempt(), attempt()];
    expect(results.filter(Boolean)).toHaveLength(1);
    expect(shared).toHaveLength(1);
    expect(pointsAwarded).toBe(1);
  });
});

describe("regression: approval-gated reopen (the reported defect)", () => {
  const today = day("2026-10-09");

  it("reopens an approval-gated recurring mission once the parent approves it", () => {
    const approved: CompletionLike[] = [{ status: "APPROVED", occurrenceKey: "D:2026-10-09" }];
    expect(blocked(approved, { now: today, requiresApproval: true })).toBe(false);
  });

  it("keeps an approval-gated mission locked while the parent has not decided", () => {
    expect(
      blocked([{ status: "AWAITING_APPROVAL", occurrenceKey: "D:2026-10-09" }], {
        now: today,
        requiresApproval: true,
      })
    ).toBe(true);
  });

  it("keeps an auto-approved mission locked for the occurrence so points cannot be farmed", () => {
    expect(
      blocked([{ status: "APPROVED", occurrenceKey: "D:2026-10-09" }], {
        now: today,
        requiresApproval: false,
      })
    ).toBe(true);
    // A different day is a different occurrence, so it unlocks.
    expect(
      blocked([{ status: "APPROVED", occurrenceKey: "D:2026-10-08" }], {
        now: today,
        requiresApproval: false,
      })
    ).toBe(false);
  });
});

describe("regression: legacy completions written before occurrenceKey existed", () => {
  const today = day("2026-10-09");

  it("derives the key from completedAt so old rows still block their own day", () => {
    // Auto-approved so only the derived key can explain the result.
    expect(
      blocked([{ status: "APPROVED", completedAt: today }], { now: today, requiresApproval: false })
    ).toBe(true);
  });

  it("stops blocking once the legacy row belongs to another day", () => {
    expect(
      blocked([{ status: "APPROVED", completedAt: day("2026-10-08") }], {
        now: today,
        requiresApproval: false,
      })
    ).toBe(false);
  });

  it("accepts Firestore Timestamps as well as ISO strings", () => {
    const timestamp = { toDate: () => day("2026-10-09") };
    expect(
      blocked([{ status: "APPROVED", completedAt: timestamp }], {
        now: today,
        requiresApproval: false,
      })
    ).toBe(true);
    expect(
      blocked([{ status: "APPROVED", completedAt: "2026-10-09T12:00:00.000Z" }], {
        now: today,
        requiresApproval: false,
      })
    ).toBe(true);
  });

  it("fails closed when a row cannot be resolved, so points can never be farmed", () => {
    expect(blocked([{ status: "AWAITING_APPROVAL", completedAt: null }], { now: today })).toBe(
      true
    );
    expect(
      blocked([{ status: "APPROVED", completedAt: null }], { now: today, requiresApproval: false })
    ).toBe(true);
  });
});


describe("resolveRequiresApproval", () => {
  it("prefers the explicit approval behaviour", () => {
    expect(resolveRequiresApproval({ approvalBehavior: "alwaysRequireApproval" }, false)).toBe(true);
    expect(resolveRequiresApproval({ approvalBehavior: "autoApprove" }, true)).toBe(false);
  });
  it("falls back to the legacy flag, then the family default", () => {
    expect(resolveRequiresApproval({ requiresApproval: false }, true)).toBe(false);
    expect(resolveRequiresApproval({}, false)).toBe(false);
    expect(resolveRequiresApproval({}, true)).toBe(true);
  });
});
