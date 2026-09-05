import XCTest
@testable import Kiddotasks

/// Verifies the local-store plumbing the CloudSyncEngine depends on:
/// bootstrapping with real cloud IDs, remote apply (no echo), the change hook,
/// and session restore. These run entirely without Firebase.
final class CloudSyncStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LocalFamilyDataStore().deleteAllLocalData()
    }

    override func tearDown() {
        LocalFamilyDataStore().deleteAllLocalData()
        super.tearDown()
    }

    private func makeRemoteSnapshot(familyId: String = "fam-cloud", parentId: String = "uid-123") -> FamilySnapshot {
        let family = Family(id: familyId, name: "Cloud Family", memberIds: [parentId])
        let parent = Parent(
            id: parentId,
            email: "pat@example.com",
            displayName: "Pat",
            familyId: familyId,
            role: .owner,
            lastSignInAt: Date()
        )
        let child = Child(id: "child-1", name: "Cloud Kid", familyId: familyId)
        let task = KiddoTask(
            id: "task-1",
            familyId: familyId,
            name: "Cloud chore",
            pointValue: 10,
            createdBy: parentId
        )
        return FamilySnapshot(
            family: family,
            parent: parent,
            passwordHash: "",
            children: [child],
            tasks: [task],
            completions: [],
            rewards: [],
            claims: [],
            transactions: [],
            achievements: []
        )
    }

    /// Cloud sign-up seeds local state with the Firebase-provided IDs.
    func testSeedLocalFamilyAfterCloudBootstrapUsesCloudIDs() throws {
        let store = LocalFamilyDataStore()
        var changeFired = false
        store.onLocalChanges = { changeFired = true }

        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: "fam-cloud",
            parentId: "uid-123",
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "PAT@Example.com"
        )

        XCTAssertEqual(store.family?.id, "fam-cloud")
        XCTAssertEqual(store.parent?.id, "uid-123")
        XCTAssertEqual(store.parent?.email, "pat@example.com")
        // Parent is the first member; starter children are appended by seeding.
        XCTAssertTrue(store.family?.memberIds.first == "uid-123")
        XCTAssertEqual(store.family?.memberIds.count, 3, "parent + two starter children")
        XCTAssertTrue(store.isAuthenticated)
        // Starter content is seeded so the first cloud push has data.
        XCTAssertFalse(store.children.isEmpty)
        XCTAssertFalse(store.tasks.isEmpty)
        // Seeding must NOT echo back through the change hook.
        XCTAssertFalse(changeFired, "bootstrap seeding should not trigger a push")
    }

    /// A fresh store instance restores the session seeded by cloud bootstrap.
    func testSeedStoresSessionForRestore() throws {
        let store = LocalFamilyDataStore()
        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: "fam-cloud",
            parentId: "uid-123",
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com"
        )

        let restored = LocalFamilyDataStore()
        XCTAssertTrue(restored.isAuthenticated, "session should restore on the next launch")
        XCTAssertEqual(restored.family?.id, "fam-cloud")
        XCTAssertEqual(restored.parent?.id, "uid-123")
    }

    /// Applying a remote snapshot replaces state and does NOT echo a push.
    func testApplyRemoteReplacesStateWithoutEcho() throws {
        let store = LocalFamilyDataStore()
        var changeFired = false
        store.onLocalChanges = { changeFired = true }

        store.applyRemote(makeRemoteSnapshot())

        XCTAssertFalse(changeFired, "remote apply must not trigger a push")
        XCTAssertEqual(store.family?.name, "Cloud Family")
        XCTAssertEqual(store.children.count, 1)
        XCTAssertEqual(store.children.first?.name, "Cloud Kid")
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks.first?.id, "task-1")
    }
/// A normal local mutation still fires the change hook (pushes upward).
    func testMutationFiresChangeHook() throws {
        let store = LocalFamilyDataStore()
        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: "fam-cloud",
            parentId: "uid-123",
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com"
        )

        var changeFired = false
        store.onLocalChanges = { changeFired = true }

        try store.addChild(name: "New Kid", avatar: .default, dateOfBirth: nil)
        XCTAssertTrue(changeFired, "a normal mutation should schedule a cloud push")
    }

    /// The snapshot builder hands the engine the full current state.
    func testCurrentSnapshotReflectsState() throws {
        let store = LocalFamilyDataStore()
        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: "fam-cloud",
            parentId: "uid-123",
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com"
        )

        let snapshot = store.currentSnapshot()
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.family.id, "fam-cloud")
        XCTAssertEqual(snapshot?.parent.id, "uid-123")
        XCTAssertEqual(snapshot?.children.count, store.children.count)
        XCTAssertEqual(snapshot?.tasks.count, store.tasks.count)
    }

    /// Sign-out clears the cloud-seeded session.
    func testSignOutClearsCloudSession() throws {
        let store = LocalFamilyDataStore()
        try store.seedLocalFamilyAfterCloudBootstrap(
            familyId: "fam-cloud",
            parentId: "uid-123",
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com"
        )
        XCTAssertTrue(store.isAuthenticated)

        store.signOut()
        XCTAssertFalse(store.isAuthenticated)

        let restored = LocalFamilyDataStore()
        XCTAssertFalse(restored.isAuthenticated, "sign-out should clear the session")
    }
}