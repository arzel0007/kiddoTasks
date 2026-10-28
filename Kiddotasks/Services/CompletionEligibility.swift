import Foundation

/// Swift mirror of `Firebase/functions/src/occurrence.ts` (the authoritative
/// copy) and `apps/web/src/lib/occurrence.ts`. Keep all three in lockstep so
/// phone, iPad and web always agree on whether a mission may be submitted.
///
/// Rules:
///  1. `oneTime` missions are blocked forever by ANY non-rejected completion.
///  2. Recurring missions (daily / weekdays / weekly / custom) are blocked only
///     for the SAME occurrence — `D:YYYY-MM-DD` for daily-style recurrence and
///     `W:YYYY-Www` (ISO week) for weekly.
///  3. A completion still waiting for a parent always blocks its occurrence.
///  4. Once a parent has decided an approval-gated recurring mission it reopens.
///  5. Auto-approved recurring missions stay locked for the occurrence.
///  6. `rejected` never blocks anything.
///
/// Everything here is pure so it can be unit-tested without a store.
enum CompletionEligibility {

    // MARK: - Occurrence keys

    /// The occurrence a moment belongs to, or `nil` for one-time missions
    /// (which are never occurrence-scoped).
    ///
    /// The key is built from the *local* calendar date, then — for weekly
    /// missions — collapsed to the ISO week of that date. Building the date
    /// first and the week second is what keeps this byte-identical to the
    /// server, which reads the day in the family's IANA time zone.
    static func occurrenceKey(
        for recurrence: TaskRecurrence,
        at date: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard recurrence.type != .oneTime else { return nil }
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return nil
        }
        if recurrence.type == .weekly {
            return isoWeekKey(year: year, month: month, day: day)
        }
        return String(format: "D:%04d-%02d-%02d", year, month, day)
    }

    /// ISO-8601 week (`YYYY-Www`) of a proleptic-Gregorian calendar date.
    private static func isoWeekKey(year: Int, month: Int, day: Int) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let moment = utc.date(
            from: DateComponents(year: year, month: month, day: day, hour: 12)
        ) else {
            return String(format: "W:%04d-W01", year)
        }
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = utc.timeZone
        let week = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: moment)
        return String(
            format: "W:%04d-W%02d",
            week.yearForWeekOfYear ?? year,
            week.weekOfYear ?? 1
        )
    }

    /// The occurrence a stored completion belongs to. Rows written before
    /// `occurrenceKey` existed fall back to their `completedAt`. `nil` means
    /// "cannot be resolved" and callers treat it as matching, so a malformed
    /// historical row can never be used to farm points.
    static func occurrenceKey(
        of completion: TaskCompletion,
        for recurrence: TaskRecurrence,
        calendar: Calendar = .current
    ) -> String? {
        guard recurrence.type != .oneTime else { return nil }
        if let stored = completion.occurrenceKey, !stored.isEmpty { return stored }
        return occurrenceKey(for: recurrence, at: completion.completedAt, calendar: calendar)
    }

    // MARK: - Queries

    /// Every non-rejected completion of `task` for `childId` that belongs to
    /// the occurrence at `now`. For one-time missions this is simply every
    /// non-rejected completion ever recorded.
    static func occurrences(
        of task: KiddoTask,
        childId: String,
        in completions: [TaskCompletion],
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskCompletion] {
        let mine = completions.filter { $0.taskId == task.id && $0.childId == childId }
        let notRejected = mine.filter { $0.status != .rejected }
        guard task.recurrence.type != .oneTime else { return notRejected }
        guard let currentKey = occurrenceKey(for: task.recurrence, at: now, calendar: calendar) else {
            return []
        }
        return notRejected.filter { completion in
            let key = occurrenceKey(of: completion, for: task.recurrence, calendar: calendar)
            // NOTE: No `key == nil` fallback. Legacy rows with missing
            // `occurrenceKey` MUST NOT block a fresh submission — otherwise any
            // historical row (even for a different day) would permanently lock
            // the task for the family.
            return key == currentKey
        }
    }

    /// The status the Kids Station card shows — always the current occurrence,
    /// never a historical one. A rejection is included so the card can still
    /// explain why the mission is available again; use `blockingCompletion`
    /// separately to decide whether the action is enabled.
    static func latestOccurrence(
        of task: KiddoTask,
        childId: String,
        in completions: [TaskCompletion],
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskCompletion? {
        let mine = completions.filter { $0.taskId == task.id && $0.childId == childId }
        guard task.recurrence.type != .oneTime else { return mine.last }
        guard let currentKey = occurrenceKey(for: task.recurrence, at: now, calendar: calendar) else {
            return nil
        }
        return mine.last { completion in
            let key = occurrenceKey(of: completion, for: task.recurrence, calendar: calendar)
            // NOTE: Only current-occurrence completions are shown — a historical
            // completion from a different day must not be displayed as the
            // current status.
            return key == currentKey
        }
    }

    /// The completion that stops the child submitting again, or `nil` when the
    /// mission is eligible. Must equal the server's verdict.
    static func blockingCompletion(
        of task: KiddoTask,
        childId: String,
        in completions: [TaskCompletion],
        at now: Date = Date(),
        requiresApproval: Bool,
        calendar: Calendar = .current
    ) -> TaskCompletion? {
        // Rule 1 — one-time missions never come back.
        guard task.recurrence.type != .oneTime else {
            return completions.first {
                $0.taskId == task.id && $0.childId == childId && $0.status != .rejected
            }
        }

        let sameOccurrence = occurrences(
            of: task, childId: childId, in: completions, at: now, calendar: calendar
        )
        guard !sameOccurrence.isEmpty else { return nil }

        // Rule 3 — a parent decision is still pending.
        if let pending = sameOccurrence.first(where: {
            $0.status == .awaitingApproval || $0.status == .completed
        }) {
            return pending
        }

        // Rule 5 — auto-approved missions are once per occurrence.
        guard requiresApproval else { return sameOccurrence.last }

        // Rule 4 — the parent already approved this occurrence → reopen.
        return nil
    }

    /// `true` when the mission may be submitted again right now.
    static func canSubmit(
        task: KiddoTask,
        childId: String,
        in completions: [TaskCompletion],
        at now: Date = Date(),
        requiresApproval: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        blockingCompletion(
            of: task,
            childId: childId,
            in: completions,
            at: now,
            requiresApproval: requiresApproval,
            calendar: calendar
        ) == nil
    }
}

