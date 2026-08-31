import Foundation
import Observation

/// Represents a child's reward claim/request
@Observable
final class RewardClaim: Identifiable, Codable {
    let id: String
    let familyId: String
    let rewardId: String
    let childId: String
    var status: RewardClaimStatus
    let claimedAt: Date
    var approvedAt: Date?
    var approvedBy: String?                   // Parent ID
    var pointDeductionTransactionId: String?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case rewardId
        case childId
        case status
        case claimedAt
        case approvedAt
        case approvedBy
        case pointDeductionTransactionId
        case notes
    }
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        rewardId: String,
        childId: String,
        status: RewardClaimStatus = .claimed,
        claimedAt: Date = Date(),
        approvedAt: Date? = nil,
        approvedBy: String? = nil,
        pointDeductionTransactionId: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.rewardId = rewardId
        self.childId = childId
        self.status = status
        self.claimedAt = claimedAt
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.pointDeductionTransactionId = pointDeductionTransactionId
        self.notes = notes
    }
    
    /// Check if claim is pending parent decision
    var isPending: Bool {
        status == .claimed
    }
    
    /// Check if claim has been finalized
    var isFinalized: Bool {
        status == .redeemed || status == .rejected
    }
}

/// Reward claim status lifecycle
enum RewardClaimStatus: String, Codable {
    case claimed = "CLAIMED"                  // Requested, awaiting approval
    case approved = "APPROVED"                // Parent approved, points deducted
    case redeemed = "REDEEMED"                // Reward has been given/used
    case rejected = "REJECTED"                // Parent rejected
    
    var displayName: String {
        switch self {
        case .claimed:
            return "Claimed"
        case .approved:
            return "Approved"
        case .redeemed:
            return "Redeemed ✓"
        case .rejected:
            return "Not approved"
        }
    }
    
    var isPending: Bool {
        self == .claimed
    }
    
    var isApproved: Bool {
        self == .approved || self == .redeemed
    }
}
