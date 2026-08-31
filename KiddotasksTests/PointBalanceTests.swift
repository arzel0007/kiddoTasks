import XCTest
@testable import Kiddotasks

final class PointBalanceTests: XCTestCase {
    func testPositiveTransactionIncreasesBalance() {
        var balance = PointBalance(childId: "child", familyId: "family")
        let earned = PointTransaction(
            familyId: "family",
            childId: "child",
            amount: 15,
            type: .taskCompletion,
            description: "Make bed"
        )
        balance.applyTransaction(earned)
        XCTAssertEqual(balance.activePoints, 15)
        XCTAssertEqual(balance.totalEarned, 15)
        XCTAssertEqual(balance.totalSpent, 0)
    }

    func testRedemptionDecreasesBalance() {
        var balance = PointBalance(childId: "child", familyId: "family")
        balance.applyTransaction(
            PointTransaction(
                familyId: "family",
                childId: "child",
                amount: 50,
                type: .taskCompletion,
                description: "Chores"
            )
        )
        balance.applyTransaction(
            PointTransaction(
                familyId: "family",
                childId: "child",
                amount: -30,
                type: .rewardRedemption,
                description: "Screen time"
            )
        )
        XCTAssertEqual(balance.activePoints, 20)
        XCTAssertEqual(balance.totalSpent, 30)
    }

    func testReversedTransactionIsIgnored() {
        var balance = PointBalance(childId: "child", familyId: "family")
        var tx = PointTransaction(
            familyId: "family",
            childId: "child",
            amount: 10,
            type: .taskCompletion,
            description: "Oops"
        )
        tx.isReversed = true
        balance.applyTransaction(tx)
        XCTAssertEqual(balance.activePoints, 0)
    }
}
