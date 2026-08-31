import Foundation

/// Immutable point transaction record (audit trail)
struct PointTransaction: Identifiable, Codable {
    let id: String
    let familyId: String
    let childId: String
    let amount: Int                           // Can be negative
    let type: TransactionType
    let relatedId: String?                    // taskId, rewardClaimId, etc
    let description: String
    let createdAt: Date
    let createdBy: String?                    // Parent ID or system
    var isReversed: Bool = false
    var reversalTransactionId: String?        // ID of reversal transaction
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case childId
        case amount
        case type
        case relatedId
        case description
        case createdAt
        case createdBy
        case isReversed
        case reversalTransactionId
    }
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        childId: String,
        amount: Int,
        type: TransactionType,
        relatedId: String? = nil,
        description: String,
        createdAt: Date = Date(),
        createdBy: String? = nil,
        isReversed: Bool = false,
        reversalTransactionId: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.childId = childId
        self.amount = amount
        self.type = type
        self.relatedId = relatedId
        self.description = description
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.isReversed = isReversed
        self.reversalTransactionId = reversalTransactionId
    }
    
    /// Create a reversal transaction
    func createReversal(by parentId: String) -> PointTransaction {
        PointTransaction(
            familyId: familyId,
            childId: childId,
            amount: -amount,
            type: .reversal,
            relatedId: self.id,
            description: "Reversal of: \(description)",
            createdBy: parentId,
            reversalTransactionId: self.id
        )
    }
}

/// Types of point transactions
enum TransactionType: String, Codable, CaseIterable {
    case taskCompletion = "TASK_COMPLETION"
    case bonus = "BONUS"
    case rewardRedemption = "REWARD_REDEMPTION"
    case manualAdjustment = "MANUAL_ADJUSTMENT"
    case reversal = "REVERSAL"
    
    var displayName: String {
        switch self {
        case .taskCompletion:
            return "Task Completed"
        case .bonus:
            return "Bonus Points"
        case .rewardRedemption:
            return "Reward Claimed"
        case .manualAdjustment:
            return "Adjustment"
        case .reversal:
            return "Reversal"
        }
    }
    
    var icon: String {
        switch self {
        case .taskCompletion:
            return "checkmark.circle.fill"
        case .bonus:
            return "star.fill"
        case .rewardRedemption:
            return "gift.fill"
        case .manualAdjustment:
            return "pencil.circle.fill"
        case .reversal:
            return "arrow.uturn.left.circle.fill"
        }
    }
}

/// Point balance summary (derived from transactions)
struct PointBalance: Codable {
    let childId: String
    let familyId: String
    var activePoints: Int                     // Current balance
    var totalEarned: Int                      // All positive transactions
    var totalSpent: Int                       // All negative transactions
    var lastUpdated: Date
    
    var netChange: Int {
        totalEarned - totalSpent
    }
    
    init(childId: String, familyId: String) {
        self.childId = childId
        self.familyId = familyId
        self.activePoints = 0
        self.totalEarned = 0
        self.totalSpent = 0
        self.lastUpdated = Date()
    }
    
    /// Update balance from a transaction
    mutating func applyTransaction(_ transaction: PointTransaction) {
        if !transaction.isReversed {
            if transaction.amount > 0 {
                totalEarned += transaction.amount
            } else {
                totalSpent += abs(transaction.amount)
            }
            activePoints = totalEarned - totalSpent
            lastUpdated = Date()
        }
    }
}
