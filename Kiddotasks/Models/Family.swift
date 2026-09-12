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
    /// Download URL in Firebase Storage when cloud sync is enabled.
    var photoURL: String?
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
        case photoURL
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
        photoURL: String? = nil,
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
        self.photoURL = photoURL
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
    /// When true, Kids Space shows the Play tab (basketball mini-game).
    var enableMiniGames: Bool = true
    /// Max minutes for basketball per session (0 = unlimited / default game length).
    var basketballMaxMinutes: Int = 0
    /// How family tallies allowance-style rewards (in addition to stars).
    var allowanceMode: AllowanceMode = .starsOnly
    /// Currency units paid for a day with any approved completion (flatDaily).
    var flatDailyAmount: Double = 1
    /// Bonus message when a child completes every due chore for a full week.
    var weekBonusTitle: String = "Full week!"
    /// Plan for this family (free | plus). Stripe can upgrade this later.
    var plan: String = "free"

    static let `default` = FamilySettings()

    enum CodingKeys: String, CodingKey {
        case pointDisplaySymbol
        case enableNotifications
        case celebrationAnimationsEnabled
        case requireApprovalByDefault
        case weekStartsOn
        case kidsStationPIN
        case enableMiniGames
        case basketballMaxMinutes
        case allowanceMode
        case flatDailyAmount
        case weekBonusTitle
        case plan
    }

    init(
        pointDisplaySymbol: String = "⭐",
        enableNotifications: Bool = true,
        celebrationAnimationsEnabled: Bool = true,
        requireApprovalByDefault: Bool = true,
        weekStartsOn: Int = 1,
        kidsStationPIN: String = "1234",
        enableMiniGames: Bool = true,
        basketballMaxMinutes: Int = 0,
        allowanceMode: AllowanceMode = .starsOnly,
        flatDailyAmount: Double = 1,
        weekBonusTitle: String = "Full week!",
        plan: String = "free"
    ) {
        self.pointDisplaySymbol = pointDisplaySymbol
        self.enableNotifications = enableNotifications
        self.celebrationAnimationsEnabled = celebrationAnimationsEnabled
        self.requireApprovalByDefault = requireApprovalByDefault
        self.weekStartsOn = weekStartsOn
        self.kidsStationPIN = kidsStationPIN
        self.enableMiniGames = enableMiniGames
        self.basketballMaxMinutes = basketballMaxMinutes
        self.allowanceMode = allowanceMode
        self.flatDailyAmount = flatDailyAmount
        self.weekBonusTitle = weekBonusTitle
        self.plan = plan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pointDisplaySymbol = try c.decodeIfPresent(String.self, forKey: .pointDisplaySymbol) ?? "⭐"
        enableNotifications = try c.decodeIfPresent(Bool.self, forKey: .enableNotifications) ?? true
        celebrationAnimationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .celebrationAnimationsEnabled) ?? true
        requireApprovalByDefault = try c.decodeIfPresent(Bool.self, forKey: .requireApprovalByDefault) ?? true
        weekStartsOn = try c.decodeIfPresent(Int.self, forKey: .weekStartsOn) ?? 1
        kidsStationPIN = try c.decodeIfPresent(String.self, forKey: .kidsStationPIN) ?? "1234"
        enableMiniGames = try c.decodeIfPresent(Bool.self, forKey: .enableMiniGames) ?? true
        basketballMaxMinutes = try c.decodeIfPresent(Int.self, forKey: .basketballMaxMinutes) ?? 0
        allowanceMode = try c.decodeIfPresent(AllowanceMode.self, forKey: .allowanceMode) ?? .starsOnly
        flatDailyAmount = try c.decodeIfPresent(Double.self, forKey: .flatDailyAmount) ?? 1
        weekBonusTitle = try c.decodeIfPresent(String.self, forKey: .weekBonusTitle) ?? "Full week!"
        plan = try c.decodeIfPresent(String.self, forKey: .plan) ?? "free"
    }
}
