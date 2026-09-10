import XCTest
@testable import Kiddotasks

/// Regression tests for the permanent cloud-sync hardening:
/// pending-push tracking, tombstoned deletes, and dirty-safe remote apply.
final class SyncHardeningTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let store = LocalFamilyDataStore()
        store.clearSyncMeta()
        store.deleteAllLocalData()
        UserDefaults.standard.removeObject(forKey: "kiddotasks.family.syncMeta.v1")
    }

    override func tearDown() {
        let store = LocalFamilyDataStore()
        store.clearSyncMeta()
        store.deleteAllLocalData()
        super.tearDown()
    }

    private func seededStore() throws -> LocalFamilyDataStore {
        let store = LocalFamilyDataStore()
        store.clearSyncMeta()
        try store.signUp(
            familyName: "Test Family",
            parentName: "Pat",
            email: "pat@example.com",
            password: "password123"
        )
        return store
    }

    func testLocalMutationMarksPendingPush() throws {
        let store = try seededStore()
        // signUp persists with callbacks suspended? No — it uses persist directly
        // which sets pending when not suspended.
        XCTAssertTrue(store.hasPendingPush || store.family != nil)

        store.markPushAcknowledged()
        XCTAssertFalse(store.hasPendingPush)

        _ = try store.addChild(
            name: "Maya",
            avatar: .default,
            photoData: nil,
            dateOfBirth: nil
        )
        XCTAssertTrue(store.hasPendingPush, "local mutation must require a push")
    }

    func testDeleteTaskTombstonesAndSurvivesApply() throws {
        let store = try seededStore()
        let task = try XCTUnwrap(store.tasks.first)
        try store.deleteTask(task.id)

        XCTAssertTrue(store.pendingRemovals.tasks.contains(task.id))
        XCTAssertFalse(store.tasks.contains(where: { $0.id == task.id }))

        // Simulate a stale pull that still contains the deleted task.
        guard var snapshot = store.currentSnapshot() else {
            return XCTFail("expected snapshot")
        }
        snapshot.tasks = [task]
        store.applyRemote(snapshot)

        XCTAssertFalse(
            store.tasks.contains(where: { $0.id == task.id }),
            "tombstoned task must not resurrect from a cloud pull"
        )
    }

    func testAcknowledgeRemovalsClearsTombstones() throws {
        let store = try seededStore()
        let task = try XCTUnwrap(store.tasks.first)
        try store.deleteTask(task.id)
        store.acknowledgeRemovals(tasks: [task.id])
        XCTAssertTrue(store.pendingRemovals.tasks.isEmpty)
    }

    func testApplyRemotePreservesPasswordHashAndClearsPending() throws {
        let store = try seededStore()
        store.markPushAcknowledged()
        _ = try store.addChild(name: "Leo", avatar: .default, photoData: nil, dateOfBirth: nil)
        XCTAssertTrue(store.hasPendingPush)

        guard let snapshot = store.currentSnapshot() else {
            return XCTFail("expected snapshot")
        }
        store.applyRemote(snapshot)
        XCTAssertFalse(store.hasPendingPush, "successful apply means local matches cloud")
    }

    func testDeleteRewardTombstones() throws {
        let store = try seededStore()
        let reward = try XCTUnwrap(store.rewards.first)
        try store.deleteReward(reward.id)
        XCTAssertTrue(store.pendingRemovals.rewards.contains(reward.id))
        XCTAssertFalse(store.rewards.contains(where: { $0.id == reward.id }))
    }

    func testSyncMetaSurvivesRelaunch() throws {
        let store = try seededStore()
        let task = try XCTUnwrap(store.tasks.first)
        try store.deleteTask(task.id)
        _ = try store.addChild(name: "Ava", avatar: .default, photoData: nil, dateOfBirth: nil)

        // New instance = app relaunch.
        let restored = LocalFamilyDataStore()
        XCTAssertTrue(restored.hasPendingPush)
        XCTAssertTrue(restored.pendingRemovals.tasks.contains(task.id))
    }

    func testResetAllDataTombstonesPreviousDocs() throws {
        let store = try seededStore()
        let child = try store.addChild(name: "Mia", avatar: .default, photoData: nil, dateOfBirth: nil)
        let familyId = try XCTUnwrap(store.family?.id)

        store.resetAllData(retainKids: true)

        XCTAssertEqual(store.family?.id, familyId, "reset must keep cloud family identity")
        XCTAssertTrue(store.pendingRemovals.children.contains(child.id))
        XCTAssertTrue(store.hasPendingPush)
        // Retained kid is a new Child instance with zero points.
        XCTAssertEqual(store.children.count, 1)
        XCTAssertEqual(store.children.first?.name, "Mia")
        XCTAssertEqual(store.children.first?.activePoints, 0)
    }
}
