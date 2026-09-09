import XCTest
@testable import Kiddotasks

/// Covers the free-tier local notification fallback: pure snapshot diffing.
/// No `UNUserNotificationCenter` is touched — only `FamilyChangeDetector`.
final class FamilyChangeDetectorTests: XCTestCase {

    private var now: Date { Date() }

    private func makeSnapshot() -> FamilySnapshot {
        let family = Family(id: "fam", name: "Testers", memberIds: ["parent-1", "child-1"])
        let parent = Parent(
            id: "parent-1", email: "p@example.com",
            displayName: "Pat", familyId: "fam", role: .owner
        )
        let child = Child(id: "child-1", name: "Maya", familyId: "fam")
        let task = KiddoTask(
            id: "task-1", familyId: "fam", name: "Clean room",
            createdBy: "parent-1"
        )
        let reward = Reward(
            id: "reward-1", familyId: "fam", name: "Movie night",
            pointCost: 30, createdBy: "parent-1"
        )
        return FamilySnapshot(
            family: family, parent: parent, passwordHash: "",
            children: [child], tasks: [task],
            completions: [], rewards: [reward],
            claims: [], transactions: [], achievements: []
        )
    }

    private func lookups(for snapshot: FamilySnapshot) -> (
        childNames: [String: String],
        taskNames: [String: String],
        rewardNames: [String: (name: String, cost: Int)]
    ) {
        (
            Dictionary(uniqueKeysWithValues: snapshot.children.map { ($0.id, $0.name) }),
            Dictionary(uniqueKeysWithValues: snapshot.tasks.map { ($0.id, $0.name) }),
            Dictionary(uniqueKeysWithValues: snapshot.rewards.map { ($0.id, ($0.name, $0.pointCost)) })
        )
    }

    private func detect(older: FamilySnapshot?, newer: FamilySnapshot) -> [FamilyChangeEvent] {
        let maps = lookups(for: newer)
        return FamilyChangeDetector.detectChanges(
            older: older, newer: newer,
            childNames: maps.childNames, taskNames: maps.taskNames,
            rewardNames: maps.rewardNames, now: now
        )
    }

    // MARK: - Completions

    func testNewAwaitingApprovalCompletionEmitsTaskSubmitted() {
        var older = makeSnapshot()
        var newer = makeSnapshot()
        let completion = TaskCompletion(
            familyId: "fam", taskId: "task-1", childId: "child-1",
            status: .awaitingApproval, completedAt: now
        )
        newer.completions = [completion]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .taskSubmitted)
        XCTAssertTrue(events[0].body.contains("Maya"))
        XCTAssertTrue(events[0].body.contains("Clean room"))
    }


    func testApprovalTransitionEmitsTaskApprovedWithPoints() {
        let completion = TaskCompletion(
            familyId: "fam", taskId: "task-1", childId: "child-1",
            status: .awaitingApproval, completedAt: now
        )
        var older = makeSnapshot()
        older.completions = [completion]
        var newer = makeSnapshot()
        let approved = TaskCompletion(
            id: completion.id, familyId: "fam", taskId: "task-1",
            childId: "child-1", status: .approved,
            completedAt: now, approvedAt: now,
            approvedBy: "parent-1", pointsAwarded: 5
        )
        newer.completions = [approved]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .taskApproved)
        XCTAssertTrue(events[0].body.contains("+5⭐"))
    }

    func testStaleCompletionIsIgnoredByRecencyGuard() {
        let older = makeSnapshot()
        var newer = makeSnapshot()
        let stale = TaskCompletion(
            familyId: "fam", taskId: "task-1", childId: "child-1",
            status: .awaitingApproval,
            completedAt: now.addingTimeInterval(-3600)
        )
        newer.completions = [stale]

        XCTAssertTrue(detect(older: older, newer: newer).isEmpty)
    }

    func testSelfCreatedCompletionDoesNotNotify() {
        let older = makeSnapshot()
        var newer = makeSnapshot()
        let mine = TaskCompletion(
            familyId: "fam", taskId: "task-1", childId: "child-1",
            status: .awaitingApproval, completedAt: now
        )
        newer.completions = [mine]
        let maps = lookups(for: newer)

        let events = FamilyChangeDetector.detectChanges(
            older: older, newer: newer, knownLocalIds: [mine.id],
            childNames: maps.childNames, taskNames: maps.taskNames,
            rewardNames: maps.rewardNames, now: now
        )

        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Reward claims

    func testNewRewardClaimEmitsRewardClaimed() {
        let older = makeSnapshot()
        var newer = makeSnapshot()
        newer.claims = [RewardClaim(
            familyId: "fam", rewardId: "reward-1", childId: "child-1",
            status: .claimed, claimedAt: now
        )]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .rewardClaimed)
        XCTAssertTrue(events[0].body.contains("Movie night"))
        XCTAssertTrue(events[0].body.contains("30⭐"))
        XCTAssertEqual(events[0].title, "Reward requested")
    }

    func testClaimApprovalTransitionEmitsRewardApproved() {
        let claim = RewardClaim(
            familyId: "fam", rewardId: "reward-1", childId: "child-1",
            status: .claimed, claimedAt: now
        )
        var older = makeSnapshot()
        older.claims = [claim]
        var newer = makeSnapshot()
        newer.claims = [RewardClaim(
            id: claim.id, familyId: "fam", rewardId: "reward-1",
            childId: "child-1", status: .approved,
            claimedAt: now, approvedAt: now, approvedBy: "parent-1"
        )]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .rewardApproved)
    }

    func testClaimRejectionIncludesReason() {
        let claim = RewardClaim(
            familyId: "fam", rewardId: "reward-1", childId: "child-1",
            status: .claimed, claimedAt: now
        )
        var older = makeSnapshot()
        older.claims = [claim]
        var newer = makeSnapshot()
        newer.claims = [RewardClaim(
            id: claim.id, familyId: "fam", rewardId: "reward-1",
            childId: "child-1", status: .rejected,
            claimedAt: now, approvedAt: now,
            approvedBy: "parent-1", notes: "Not today"
        )]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .rewardRejected)
        XCTAssertTrue(events[0].body.contains("Not today"))
    }

    // MARK: - Point ledger

    func testManualAdjustmentEmitsPointsAdjusted() {
        let older = makeSnapshot()
        var newer = makeSnapshot()
        newer.transactions = [PointTransaction(
            familyId: "fam", childId: "child-1", amount: 10,
            type: .manualAdjustment, description: "Bonus",
            createdAt: now, createdBy: "parent-1"
        )]

        let events = detect(older: older, newer: newer)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .pointsAdjusted)
        XCTAssertTrue(events[0].body.contains("+10⭐"))
    }

    func testApprovalLedgerSideEffectsAreSkipped() {
        let older = makeSnapshot()
        var newer = makeSnapshot()
        newer.transactions = [PointTransaction(
            familyId: "fam", childId: "child-1", amount: 5,
            type: .taskCompletion, description: "Task reward",
            createdAt: now, createdBy: "parent-1"
        )]

        XCTAssertTrue(detect(older: older, newer: newer).isEmpty)
    }

    func testUnchangedSnapshotEmitsNothing() {
        let snapshot = makeSnapshot()
        XCTAssertTrue(detect(older: snapshot, newer: snapshot).isEmpty)
    }

    func testEventCopyTitles() {
        let event = FamilyChangeEvent(
            kind: .taskSubmitted, childName: "Maya",
            detail: "Clean room", extra: nil
        )
        XCTAssertEqual(event.title, "Task awaiting approval")
        XCTAssertTrue(event.body.contains("tap to review"))
    }
}