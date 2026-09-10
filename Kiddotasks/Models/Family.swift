import Foundation
import Observation

/// Represents a family in KiddoTasks
@Observable
final class Family: Identifiable, Codable {
    let id: String
    var name: String
    var memberIds: [String] // [parentId, childId1, childId2, ...]
    var familyCode: String // Unique code for sharing with other parents
    var photoData: Data?
    var settings: FamilySettings
    let createdAt: Date
    var updatedAt: Date
    /// Server-authoritative write time stamped by `pushFamilySnapshot`.
    /// Used so a stale pull cannot overwrite fresher local work.
    var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case memberIds = "members"
        case familyCode
        case photoData
        case settings
        case createdAt
        case updatedAt
        case serverUpdatedAt
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        memberIds: [String] = [],
        familyCode: String = LocalFamilyDataStore.generateFamilyCode(),
        photoData: Data? = nil,
        settings: FamilySettings = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.familyCode = familyCode
        self.photoData = photoData
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
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
