import XCTest
@testable import Kiddotasks

final class KidActionCloudRoutingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let store = LocalFamilyDataStore()
        store.clearSyncMeta()
        store.deleteAllLocalData()
    }

    override func tearDown() {
        let store = LocalFamilyDataStore()
        store.clearSyncMeta()
        store.deleteAllLocalData()
        super.tearDown()
    }

    @MainActor
    func testSignedInKidsStationUsesCloudForKidActions() throws {
        let appState = AppState()
        try appState.store.signUp(
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com",
            password: "password"
        )
        let child = try appState.store.addChild(name: "Kid", avatar: .default, dateOfBirth: nil)

        appState.interfaceOverride = .kids
        appState.currentChildProfile = child

        XCTAssertTrue(
            appState.shouldUseCloudForKidAction(cloudAvailable: true),
            "Kids Station must use the callable path even when a parent session is active on the iPad."
        )
    }

    @MainActor
    func testParentCenterLocalEditsDoNotUseKidCallableRouting() throws {
        let appState = AppState()
        try appState.store.signUp(
            familyName: "Cloud Family",
            parentName: "Pat",
            email: "pat@example.com",
            password: "password"
        )

        appState.interfaceOverride = .parent
        appState.currentChildProfile = nil
        appState.gamesModeActive = false

        XCTAssertFalse(appState.shouldUseCloudForKidAction(cloudAvailable: true))
    }

    func testCloudCompletionAcknowledgementDoesNotScheduleEchoPush() {
        let store = LocalFamilyDataStore()
        let family = Family(id: "fam-cloud", name: "Cloud Family", memberIds: ["parent"])
        let parent = Parent(
            id: "parent",
            email: "pat@example.com",
            displayName: "Pat",
            familyId: family.id,
            role: .owner,
            lastSignInAt: Date()
        )
        let child = Child(id: "child", name: "Kid", familyId: family.id)
        let task = KiddoTask(id: "task", familyId: family.id, name: "Chore", createdBy: parent.id)
        store.applyRemote(FamilySnapshot(
            family: family,
            parent: parent,
            passwordHash: "",
            passwordSalt: "",
            children: [child],
            tasks: [task],
            completions: [],
            rewards: [],
            claims: [],
            transactions: [],
            achievements: []
        ))

        var changeFired = false
        store.onLocalChanges = { changeFired = true }

        store.recordCloudSubmittedCompletion(
            id: "server-completion",
            taskId: task.id,
            childId: child.id,
            status: CompletionStatus.awaitingApproval.rawValue
        )

        XCTAssertFalse(changeFired)
        XCTAssertFalse(store.hasPendingPush)
        XCTAssertEqual(store.completions.first?.id, "server-completion")
    }
}
