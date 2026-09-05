import XCTest
@testable import Kiddotasks

final class DashboardAndCRUDTests: XCTestCase {
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today)!
    }

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
        let childA = Child(id: "child-a", name: "Alex", familyId: family.id)
        let childB = Child(
            id: "child-b",
            name: "Sam",
            familyId: family.id,
            avatar: ChildAvatar(emoji: "🦁", colorHex: "#F59E0B")
        )
        store.family = family
        store.parent = parent
        store.children = [childA, childB]
        return store
    }

    private func award(_ store: LocalFamilyDataStore, childId: String, amount: Int, on date: Date) {
        store.transactions.append(
            PointTransaction(
                familyId: store.family!.id,
                childId: childId,
                amount: amount,
                type: amount >= 0 ? .taskCompletion : .rewardRedemption,
                description: "test tx",
                createdAt: date,
                createdBy: "parent-1"
            )
        )
    }

    // MARK: Dashboard aggregations

    func testStarsEarnedSumsPositiveTransactionsForTodayOnly() {
        let store = makeStore()
        award(store, childId: "child-a", amount: 10, on: Date())
        award(store, childId: "child-b", amount: 5, on: Date())
        award(store, childId: "child-a", amount: -20, on: Date())
        award(store, childId: "child-a", amount: 99, on: yesterday)

        XCTAssertEqual(store.starsEarned(), 15)
    }

    func testStarsEarnedIgnoresReversedTransactions() {
        let store = makeStore()
        award(store, childId: "child-a", amount: 10, on: Date())
        store.transactions[0].isReversed = true

        XCTAssertEqual(store.starsEarned(), 0)
    }

    func testStarsEarnedByChildIsScopedToThatChild() {
        let store = makeStore()
        award(store, childId: "child-a", amount: 10, on: Date())
        award(store, childId: "child-b", amount: 4, on: Date())

        XCTAssertEqual(store.starsEarned(byChild: "child-a"), 10)
        XCTAssertEqual(store.starsEarned(byChild: "child-b"), 4)
    }

    func testWeeklySeriesCoversEveryChildAndDayIncludingZeroes() {
        let store = makeStore()
        award(store, childId: "child-a", amount: 7, on: Date())

        let series = store.weeklyPointsSeries(days: 7)
        XCTAssertEqual(series.count, 14) // 7 days × 2 children

        let todayA = series.first {
            Calendar.current.isDateInToday($0.date) && $0.childId == "child-a"
        }
        XCTAssertEqual(todayA?.stars, 7)

        let yesterdayB = series.first {
            Calendar.current.isDate($0.date, inSameDayAs: yesterday) && $0.childId == "child-b"
        }
        XCTAssertEqual(yesterdayB?.stars, 0)
    }
}

// MARK: Task CRUD

extension DashboardAndCRUDTests {
    func testTodayTotalsCountsPendingApprovalsClaimsAndDueTasks() {
        let store = makeStore()
        let task = KiddoTask(familyId: store.family!.id, name: "Chore", createdBy: "parent-1")
        store.tasks = [task]
        store.completions.append(
            TaskCompletion(
                familyId: store.family!.id,
                taskId: task.id,
                childId: "child-a",
                status: .awaitingApproval
            )
        )
        let reward = Reward(
            familyId: store.family!.id,
            name: "Prize",
            pointCost: 10,
            createdBy: "parent-1"
        )
        store.rewards = [reward]
        store.claims.append(
            RewardClaim(familyId: store.family!.id, rewardId: reward.id, childId: "child-a")
        )

        let totals = store.todayTotals()
        XCTAssertEqual(totals.pendingApprovals, 1)
        XCTAssertEqual(totals.pendingRewardRequests, 1)
        XCTAssertEqual(totals.tasksDueToday, 1)
        XCTAssertEqual(totals.starsEarned, 0)
        XCTAssertEqual(totals.missionsApproved, 0)
    }

    func testDeleteTaskRemovesTaskButKeepsCompletionHistory() {
        let store = makeStore()
        let task = KiddoTask(familyId: store.family!.id, name: "Chore", createdBy: "parent-1")
        store.tasks = [task]
        store.completions.append(
            TaskCompletion(familyId: store.family!.id, taskId: task.id, childId: "child-a")
        )

        XCTAssertNoThrow(try store.deleteTask(task.id))
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertEqual(store.completions.count, 1)
        XCTAssertThrowsError(try store.deleteTask("missing"))
    }

    func testArchiveAndRestoreTaskTogglesActiveState() {
        let store = makeStore()
        let task = KiddoTask(familyId: store.family!.id, name: "Chore", createdBy: "parent-1")
        store.tasks = [task]

        XCTAssertNoThrow(try store.archiveTask(task.id))
        XCTAssertFalse(task.isActive)

        XCTAssertNoThrow(try store.restoreTask(task.id))
        XCTAssertTrue(task.isActive)
    }

    func testUpdateTaskBumpsVersionAndPersistsChange() {
        let store = makeStore()
        let task = KiddoTask(familyId: store.family!.id, name: "Old name", createdBy: "parent-1")
        store.tasks = [task]
        let originalVersion = task.version

        task.name = "New name"
        XCTAssertNoThrow(try store.updateTask(task))

        XCTAssertEqual(task.version, originalVersion + 1)
        XCTAssertEqual(store.tasks.first?.name, "New name")
    }

    func testRemoveChildRemovesProfileAndMembershipButKeepsHistory() {
        let store = makeStore()
        award(store, childId: "child-a", amount: 12, on: Date())

        XCTAssertNoThrow(try store.removeChild("child-a"))
        XCTAssertFalse(store.children.contains { $0.id == "child-a" })
        XCTAssertFalse(store.family!.memberIds.contains("child-a"))
        XCTAssertEqual(store.transactions.count, 1)
        XCTAssertThrowsError(try store.removeChild("child-a"))
    }

    func testUpdateKidsPINValidation() {
        let store = makeStore()
        XCTAssertThrowsError(try store.updateKidsPIN("123"))
        XCTAssertThrowsError(try store.updateKidsPIN("abcdef"))
        XCTAssertThrowsError(try store.updateKidsPIN("1234567890"))

        XCTAssertNoThrow(try store.updateKidsPIN("4321"))
        XCTAssertEqual(store.family?.settings.kidsStationPIN, "4321")
    }

    func testSettingsTogglesUpdateFamilySettings() {
        let store = makeStore()
        XCTAssertNoThrow(try store.updateNotificationsEnabled(false))
        XCTAssertNoThrow(try store.updateCelebrationsEnabled(false))

        XCTAssertEqual(store.family?.settings.enableNotifications, false)
        XCTAssertEqual(store.family?.settings.celebrationAnimationsEnabled, false)
    }
}
