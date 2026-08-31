import Foundation
import Observation

/// Represents a family in Kiddotasks
@Observable
final class Family: Identifiable, Codable {
    let id: String
    var name: String
    var memberIds: [String] // [parentId, childId1, childId2, ...]
    var settings: FamilySettings
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case memberIds = "members"
        case settings
        case createdAt
        case updatedAt
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        memberIds: [String] = [],
        settings: FamilySettings = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Family-level settings
struct FamilySettings: Codable {
    var pointDisplaySymbol: String = "⭐"
    var enableNotifications: Bool = true
    var celebrationAnimationsEnabled: Bool = true
    var requireApprovalByDefault: Bool = true
    var weekStartsOn: Int = 1 // 1 = Monday
    var kidsStationPIN: String = "1234"

    static let `default` = FamilySettings()
}
