import XCTest
@testable import Kiddotasks

/// Regression coverage for the recurrence-aware duplicate guard.
///
/// Mirrors `Firebase/functions/src/occurrence.test.ts` — the same scenarios
/// must pass on every platform or phone / iPad / web will disagree about
/// whether a mission may be submitted again.
final class CompletionEligibilityTests: XCTestCase {
    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: today)! }
    private var lastWeek: Date { Calendar.current.date(byAdding: .day, value: -7, to: today)! }

    private func makeStore() -> LocalFamilyDataStore {
        let store = LocalFamilyDataStore()
        let family = Family(name: "Testers")
        let parent = Parent(
            id: "parent-1",
            email: "parent@example.com",
            displayName: "Pat",
            familyId: family.id,
            role: .owner,
            lastSignInAt: Date()
        )
        store.family = family
        store.parent = parent
        store.children = [Child(id: "child-a", name: "Alex", familyId: family.id)]
        return store
    }

    @discardableResult
    private func addTask(
        _ store: LocalFamilyDataStore,
        recurrence: TaskRecurrence,
        approvalBehavior: TaskApprovalBehavior = .alwaysRequireApproval,
        pointValue: Int = 5
    ) -> KiddoTask {
        let task = KiddoTask(
            id: "task-1",
            familyId: store.family!.id,
            name: "Chore",
            pointValue: pointValue,
            approvalBehavior: approvalBehavior,
            assignedChildIds: ["child-a"],
            recurrence: recurrence,
            createdBy: "parent-1"
        )
        store.tasks.append(task)
        return task
    }

    /// Seeds history the way a completion pulled from the cloud would look,
    /// including the occurrence key the server stamps on it.
    private func history(
        _ store: LocalFamilyDataStore,
        status: CompletionStatus,
        completedAt: Date,
        recurrence: TaskRecurrence
    ) {
        store.completions.append(
            TaskCompletion(
                familyId: store.family!.id,
                taskId: "task-1",
                childId: "child-a",
                status: status,
                completedAt: completedAt,
                occurrenceKey: CompletionEligibility.occurrenceKey(for: recurrence, at: completedAt)
            )
        )
    }

    // MARK: - Occurrence keys

    func testOccurrenceKeyIsScopedByRecurrence() {
        let dailyToday = CompletionEligibility.occurrenceKey(for: .daily, at: today)
        let dailyYesterday = CompletionEligibility.occurrenceKey(for: .daily, at: yesterday)
        XCTAssertTrue(dailyToday?.hasPrefix("D:") == true)
        XCTAssertNotEqual(dailyToday, dailyYesterday)

        let weeklyThisWeek = CompletionEligibility.occurrenceKey(for: .weekly, at: today)
        XCTAssertTrue(weeklyThisWeek?.hasPrefix("W:") == true)
        // A week apart can never share a key.
        XCTAssertNotEqual(weeklyThisWeek, CompletionEligibility.occurrenceKey(for: .weekly, at: lastWeek))

        // One-time missions are never occurrence-scoped.
        XCTAssertNil(CompletionEligibility.occurrenceKey(for: .oneTime, at: today))
    }

    // MARK: - 1. Same child, same task, same day across devices

    func testSameDaySubmissionIsBlockedAfterTheFirstOne() throws {
        let phone = makeStore()
        addTask(phone, recurrence: .daily)
        XCTAssertNoThrow(
            try phone.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )

        // The web sees the phone's completion, then tries the same mission.
        let web = makeStore()
        addTask(web, recurrence: .daily)
        web.completions = phone.completions
        XCTAssertThrowsError(
            try web.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        XCTAssertEqual(web.completions.count, 1)
    }

    // MARK: - 2. Daily completed yesterday → available today

    func testDailyTaskCompletedYesterdayIsAvailableToday() {
        let store = makeStore()
        addTask(store, recurrence: .daily, approvalBehavior: .autoApprove)
        history(store, status: .approved, completedAt: yesterday, recurrence: .daily)

        // Yesterday's occurrence is still locked…
        XCTAssertThrowsError(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: yesterday)
        )
        // …but today is a fresh occurrence.
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
    }

    // MARK: - 3. Weekly completed last week → available this week

    func testWeeklyTaskCompletedLastWeekIsAvailableThisWeek() {
        let store = makeStore()
        addTask(store, recurrence: .weekly, approvalBehavior: .autoApprove)
        history(store, status: .approved, completedAt: lastWeek, recurrence: .weekly)
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
    }

    // MARK: - 4. One-time task completed in the past → unavailable forever

    func testOneTimeTaskCompletedInThePastIsUnavailableForever() {
        let store = makeStore()
        addTask(store, recurrence: .oneTime)
        history(store, status: .approved, completedAt: lastWeek, recurrence: .oneTime)
        XCTAssertThrowsError(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        // Still locked weeks later.
        XCTAssertThrowsError(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
    }

    // MARK: - 5. Rejected → available again for the same occurrence

    func testRejectedCompletionReopensTheCurrentOccurrence() {
        let store = makeStore()
        addTask(store, recurrence: .daily)
        history(store, status: .rejected, completedAt: today, recurrence: .daily)
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        XCTAssertEqual(store.completions.count, 2)
    }

    // MARK: - 6. Two devices submitting simultaneously

    func testSimultaneousSubmissionsProduceOneCompletionAndNoDuplicatePoints() {
        let store = makeStore()
        addTask(store, recurrence: .daily, approvalBehavior: .autoApprove, pointValue: 5)
        // Device A's write lands first. The server runs the check and the write
        // in one transaction, so the loser re-reads AFTER A's write is visible —
        // replicating A's row models exactly that serialisation.
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )

        let deviceB = makeStore()
        addTask(deviceB, recurrence: .daily, approvalBehavior: .autoApprove, pointValue: 5)
        deviceB.completions = store.completions
        XCTAssertThrowsError(
            try deviceB.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )

        XCTAssertEqual(store.completions.count, 1, "Only one completion may exist")
        XCTAssertEqual(store.children.first?.activePoints, 5, "No duplicate points")
        XCTAssertEqual(store.transactions.filter { $0.type == .taskCompletion }.count, 1)
    }

    // MARK: - Reopen after the parent decides (the reported defect)

    func testApprovalGatedMissionReopensOnceTheParentApproves() throws {
        let store = makeStore()
        addTask(store, recurrence: .daily)
        let first = try store.submitCompletion(
            taskId: "task-1", childId: "child-a", completedAt: today
        )

        // Still waiting for the parent → locked on every device.
        XCTAssertThrowsError(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )

        try store.approveCompletion(first.id)

        // The parent decided, so the same mission may be done again today.
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        XCTAssertEqual(store.completions.count, 2)
    }

    func testAutoApprovedMissionStaysLockedForTheOccurrence() {
        let store = makeStore()
        addTask(store, recurrence: .daily, approvalBehavior: .autoApprove)
        XCTAssertNoThrow(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        // No parent in the loop, so a second run today would farm points.
        XCTAssertThrowsError(
            try store.submitCompletion(taskId: "task-1", childId: "child-a", completedAt: today)
        )
        // Yesterday is a different occurrence, so it opens up again.
        XCTAssertNoThrow(
            try store.submitCompletion(
                taskId: "task-1", childId: "child-a", completedAt: yesterday
            )
        )
    }

    // MARK: - Card state

    func testCardNeverShowsHistoricalCompletions() {
        let store = makeStore()
        addTask(store, recurrence: .daily, approvalBehavior: .autoApprove)
        history(store, status: .approved, completedAt: yesterday, recurrence: .daily)

        // Yesterday's run must not grey out today's card.
        XCTAssertNil(store.latestOccurrenceCompletion(taskId: "task-1", childId: "child-a"))
        XCTAssertNil(store.blockingCompletion(taskId: "task-1", childId: "child-a"))

        history(store, status: .approved, completedAt: today, recurrence: .daily)
        XCTAssertNotNil(store.latestOccurrenceCompletion(taskId: "task-1", childId: "child-a"))
        XCTAssertNotNil(store.blockingCompletion(taskId: "task-1", childId: "child-a"))
    }
}
