import Foundation
import Observation

/// Represents a reward definition
@Observable
final class Reward: Identifiable, Codable {
    let id: String
    let familyId: String
    var name: String
    var description: String
    var icon: String                          // SF Symbol name
    var pointCost: Int
    var eligibleChildIds: [String]            // Empty = all children
    var requiresApproval: Bool
    var isActive: Bool
    let createdBy: String                     // Parent ID
    let createdAt: Date
    var updatedAt: Date
    var version: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case name
        case description
        case icon
        case pointCost
        case eligibleChildIds
        case requiresApproval
        case isActive
        case createdBy
        case createdAt
        case updatedAt
        case version
    }
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        name: String,
        description: String = "",
        icon: String = "gift.fill",
        pointCost: Int,
        eligibleChildIds: [String] = [],
        requiresApproval: Bool = true,
        isActive: Bool = true,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.description = description
        self.icon = icon
        self.pointCost = pointCost
        self.eligibleChildIds = eligibleChildIds
        self.requiresApproval = requiresApproval
        self.isActive = isActive
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
    
    /// Check if reward is eligible for a child
    func isEligibleFor(_ childId: String) -> Bool {
        eligibleChildIds.isEmpty || eligibleChildIds.contains(childId)
    }
    
    /// Check if child can afford this reward
    func canAfford(with points: Int) -> Bool {
        points >= pointCost
    }
    
    /// Points needed to afford this reward
    func pointsNeeded(givenCurrentPoints: Int) -> Int {
        max(0, pointCost - givenCurrentPoints)
    }
}
