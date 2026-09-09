import Foundation

/// Pure diffing between two family snapshots. Returns events for everything
/// that is NEW or TRANSITIONED in `newer` relative to `older`.
///
/// Mirrors the server-side push triggers (`Firebase/functions/src/
/// notifications.ts`) so local banners and (future) remote pushes share the
/// same coverage: completions, claims, and point-ledger changes.
enum FamilyChangeDetector {

    /// Only events newer than this are reported — kills replay storms when a
    /// device pulls a big backlog (first sign-in, long offline period).
    static let recencyWindow: TimeInterval = 5 * 60

    /// Ledger types that are side effects of an approval/rejection (already
    /// notified via the status-transition event) — never notify twice.
    private static let skippedLedgerTypes: Set<String> = [
        "TASK_COMPLETION", "REWARD_REDEMPTION",
    ]

    /// - Parameters:
    ///   - older: snapshot currently shown on this device (nil on first sync).
    ///   - newer: snapshot just pulled from the cloud.
    ///   - knownLocalIds: IDs created on THIS device since the last pull.
    ///     Changes the user just performed locally must not banner back at
    ///     them; the in-app UI already reflects those instantly.
    static func detectChanges(
        older: FamilySnapshot?,
        newer: FamilySnapshot,
        knownLocalIds: Set<String> = [],
        childNames: [String: String] = [:],
        taskNames: [String: String] = [:],
        rewardNames: [String: (name: String, cost: Int)] = [:],
        now: Date = Date()
    ) -> [FamilyChangeEvent] {
        var events: [FamilyChangeEvent] = []
        let isRecent: (Date) -> Bool = { now.timeIntervalSince($0) < recencyWindow }
        let kidName: (String) -> String = { childNames[$0] ?? "Your kid" }

        // --- Completions ---------------------------------------------
        let oldCompletions = Dictionary(
            uniqueKeysWithValues: (older?.completions ?? []).map { ($0.id, $0) }
        )
        for completion in newer.completions {
            guard !knownLocalIds.contains(completion.id) else { continue }
            let taskName = taskNames[completion.taskId] ?? "a task"
            if let old = oldCompletions[completion.id] {
                guard old.status != completion.status else { continue }
            }
            if let event = completionEvent(
                for: completion, taskName: taskName,
                kidName: kidName(completion.childId), isRecent: isRecent
            ) { events.append(event) }
        }

        // --- Reward claims -------------------------------------------
        let oldClaims = Dictionary(
            uniqueKeysWithValues: (older?.claims ?? []).map { ($0.id, $0) }
        )
        for claim in newer.claims {
            guard !knownLocalIds.contains(claim.id) else { continue }
            let reward = rewardNames[claim.rewardId]
            if let old = oldClaims[claim.id] {
                guard old.status != claim.status else { continue }
            }
            if let event = claimEvent(
                for: claim, rewardName: reward?.name ?? "a reward",
                cost: reward?.cost, kidName: kidName(claim.childId),
                isRecent: isRecent
            ) { events.append(event) }
        }

        // --- Point ledger (manual adjustments / bonuses / reversals) --
        let oldTxIds = Set((older?.transactions ?? []).map { $0.id })
        for tx in newer.transactions {
            guard !oldTxIds.contains(tx.id), !knownLocalIds.contains(tx.id) else { continue }
            guard !skippedLedgerTypes.contains(tx.type.rawValue) else { continue }
            guard !tx.isReversed, isRecent(tx.createdAt) else { continue }
            let delta = tx.amount >= 0 ? "+\(tx.amount)⭐" : "\(tx.amount)⭐"
            let verb = tx.amount >= 0 ? "earned" : "lost"
            let body = "\(kidName(tx.childId)) \(verb) \(delta) — \(tx.description)"
            events.append(FamilyChangeEvent(
                kind: .pointsAdjusted, childName: kidName(tx.childId),
                detail: body, extra: nil
            ))
        }

        return events
    }

    // MARK: - Private builders

    private static func completionEvent(
        for completion: TaskCompletion,
        taskName: String,
        kidName: String,
        isRecent: (Date) -> Bool
    ) -> FamilyChangeEvent? {
        switch completion.status {
        case .awaitingApproval:
            guard isRecent(completion.completedAt) else { return nil }
            return FamilyChangeEvent(kind: .taskSubmitted, childName: kidName, detail: taskName, extra: nil)
        case .completed:
            guard isRecent(completion.completedAt) else { return nil }
            return FamilyChangeEvent(kind: .taskAutoCompleted, childName: kidName, detail: taskName, extra: nil)
        case .approved:
            guard let approvedAt = completion.approvedAt, isRecent(approvedAt) else { return nil }
            let points = completion.pointsAwarded.map { "+\($0)⭐" }
            return FamilyChangeEvent(kind: .taskApproved, childName: kidName, detail: taskName, extra: points)
        case .rejected:
            guard let approvedAt = completion.approvedAt, isRecent(approvedAt) else { return nil }
            return FamilyChangeEvent(kind: .taskRejected, childName: kidName, detail: taskName, extra: completion.notes)
        }
    }

    private static func claimEvent(
        for claim: RewardClaim,
        rewardName: String,
        cost: Int?,
        kidName: String,
        isRecent: (Date) -> Bool
    ) -> FamilyChangeEvent? {
        switch claim.status {
        case .claimed:
            guard isRecent(claim.claimedAt) else { return nil }
            return FamilyChangeEvent(
                kind: .rewardClaimed, childName: kidName,
                detail: rewardName, extra: cost.map { "\($0)⭐" })
        case .approved, .redeemed:
            guard let approvedAt = claim.approvedAt, isRecent(approvedAt) else { return nil }
            return FamilyChangeEvent(kind: .rewardApproved, childName: kidName, detail: rewardName, extra: nil)
        case .rejected:
            guard let approvedAt = claim.approvedAt, isRecent(approvedAt) else { return nil }
            return FamilyChangeEvent(kind: .rewardRejected, childName: kidName, detail: rewardName, extra: claim.notes)
        }
    }
}
