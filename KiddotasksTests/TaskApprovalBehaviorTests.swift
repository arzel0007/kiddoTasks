import XCTest
@testable import Kiddotasks

final class TaskApprovalBehaviorTests: XCTestCase {
    func testFamilyDefaultControlsInheritedTaskApproval() {
        let task = KiddoTask(familyId: "family", name: "Tidy up", createdBy: "parent")
        var settings = FamilySettings.default

        settings.requireApprovalByDefault = true
        XCTAssertTrue(task.requiresParentApproval(using: settings))

        settings.requireApprovalByDefault = false
        XCTAssertFalse(task.requiresParentApproval(using: settings))
    }

    func testTaskOverrideTakesPrecedenceOverFamilyDefault() {
        var settings = FamilySettings.default
        settings.requireApprovalByDefault = true

        let autoApproved = KiddoTask(
            familyId: "family",
            name: "Brush teeth",
            approvalBehavior: .autoApprove,
            createdBy: "parent"
        )
        XCTAssertFalse(autoApproved.requiresParentApproval(using: settings))

        settings.requireApprovalByDefault = false
        let alwaysRequiresApproval = KiddoTask(
            familyId: "family",
            name: "Read",
            approvalBehavior: .alwaysRequireApproval,
            createdBy: "parent"
        )
        XCTAssertTrue(alwaysRequiresApproval.requiresParentApproval(using: settings))
    }
}
