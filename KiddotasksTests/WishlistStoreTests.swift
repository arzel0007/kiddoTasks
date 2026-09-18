import XCTest
@testable import Kiddotasks

/// Wishlist is intentionally isolated from the points economy.
final class WishlistStoreTests: XCTestCase {

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

    private func makeSignedInStore() throws -> (LocalFamilyDataStore, Child) {
        let store = LocalFamilyDataStore()
        try store.signUp(
            familyName: "Wishlist Fam",
            parentName: "Pat",
            email: "wish@example.com",
            password: "password1"
        )
        // Premium so multi-child isolation tests can add a second kid.
        store.family?.settings.plan = "plus"
        try store.updateWishlistEnabled(true)
        let child = try store.addChild(
            name: "Maya",
            avatar: .default,
            dateOfBirth: nil
        )
        return (store, child)
    }

    func testEnableWishlistDefaultsToFalseWhenMissing() throws {
        let json = """
        {"pointDisplaySymbol":"⭐","enableNotifications":true}
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(FamilySettings.self, from: json)
        XCTAssertFalse(settings.enableWishlist)
    }

    func testAddWishlistItemDoesNotTouchPoints() throws {
        let (store, child) = try makeSignedInStore()
        let pointsBefore = child.activePoints
        let txCountBefore = store.transactions.count

        let item = try store.addWishlistItem(
            childId: child.id,
            title: "Blue bicycle",
            message: "For birthday",
            occasion: .birthday
        )

        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(store.wishlistItems.count, 1)
        XCTAssertEqual(child.activePoints, pointsBefore)
        XCTAssertEqual(store.transactions.count, txCountBefore)
    }

    func testAddWishlistItemFailsWhenDisabled() throws {
        let store = LocalFamilyDataStore()
        try store.signUp(
            familyName: "Off Fam",
            parentName: "Pat",
            email: "off@example.com",
            password: "password1"
        )
        let child = try store.addChild(name: "Leo", avatar: .default, dateOfBirth: nil)
        XCTAssertThrowsError(
            try store.addWishlistItem(childId: child.id, title: "Toy")
        )
    }

    func testReviewWishlistItemNeverAwardsOrDeductsPoints() throws {
        let (store, child) = try makeSignedInStore()
        let pointsBefore = child.activePoints
        let earnedBefore = child.totalPointsEarned
        let txCountBefore = store.transactions.count
        let item = try store.addWishlistItem(
            childId: child.id,
            title: "Science kit",
            occasion: .justBecause
        )

        try store.reviewWishlistItem(
            item.id,
            decision: .approved,
            parentResponse: "Maybe for your birthday"
        )

        XCTAssertEqual(item.status, .approved)
        XCTAssertEqual(item.parentResponse, "Maybe for your birthday")
        XCTAssertNotNil(item.reviewedAt)
        XCTAssertEqual(child.activePoints, pointsBefore)
        XCTAssertEqual(child.totalPointsEarned, earnedBefore)
        XCTAssertEqual(store.transactions.count, txCountBefore)
        XCTAssertEqual(store.pendingWishlistCount(), 0)
    }

    func testDeleteWishlistItemTombstonesId() throws {
        let (store, child) = try makeSignedInStore()
        let item = try store.addWishlistItem(childId: child.id, title: "Sketchbook")
        try store.deleteWishlistItem(item.id)
        XCTAssertTrue(store.wishlistItems.isEmpty)
        XCTAssertTrue(store.pendingRemovals.wishlistItems.contains(item.id))
    }

    func testWishlistItemsAreIsolatedByChild() throws {
        let (store, childA) = try makeSignedInStore()
        let childB = try store.addChild(name: "Sam", avatar: .default, dateOfBirth: nil)
        _ = try store.addWishlistItem(childId: childA.id, title: "A wish", occasion: .school)
        _ = try store.addWishlistItem(childId: childB.id, title: "B wish", occasion: .christmas)

        XCTAssertEqual(store.wishlistItems(forChild: childA.id).count, 1)
        XCTAssertEqual(store.wishlistItems(forChild: childB.id).count, 1)
        XCTAssertEqual(store.wishlistItems(forChild: childA.id).first?.title, "A wish")
        XCTAssertEqual(store.wishlistItems(forChild: childB.id).first?.title, "B wish")
    }
}
