import Foundation
import Observation

/// Represents a child in Kiddotasks
@Observable
final class Child: Identifiable, Codable {
    let id: String
    var name: String
    let familyId: String
    var avatar: ChildAvatar
    var dateOfBirth: Date?
    var activePoints: Int = 0
    var totalPointsEarned: Int = 0
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case familyId
        case avatar
        case dateOfBirth
        case activePoints
        case totalPointsEarned
        case createdAt
        case updatedAt
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        familyId: String,
        avatar: ChildAvatar = .default,
        dateOfBirth: Date? = nil,
        activePoints: Int = 0,
        totalPointsEarned: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.familyId = familyId
        self.avatar = avatar
        self.dateOfBirth = dateOfBirth
        self.activePoints = activePoints
        self.totalPointsEarned = totalPointsEarned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Calculate age from date of birth
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dob, to: Date())
        return components.year
    }
    
    /// Determine age group for UI/logic
    var ageGroup: AgeGroup? {
        guard let age = age else { return nil }
        return AgeGroup(age: age)
    }
}

/// Child avatar representation
struct ChildAvatar: Codable, Equatable {
    var emoji: String = "👧"
    var colorHex: String = "#EC4899"  // Pink
    
    static let `default` = ChildAvatar()
    
    static let presets: [ChildAvatar] = [
        ChildAvatar(emoji: "👧", colorHex: "#EC4899"),  // Pink
        ChildAvatar(emoji: "👦", colorHex: "#3B82F6"),  // Blue
        ChildAvatar(emoji: "🦁", colorHex: "#F59E0B"),  // Amber
        ChildAvatar(emoji: "🐢", colorHex: "#10B981"),  // Green
        ChildAvatar(emoji: "🦄", colorHex: "#A855F7"),  // Purple
        ChildAvatar(emoji: "🦋", colorHex: "#06B6D4"),  // Cyan
        ChildAvatar(emoji: "🐸", colorHex: "#14B8A6"),  // Teal
        ChildAvatar(emoji: "🦊", colorHex: "#EF4444"),  // Red
    ]
}

/// Age groups for customizing experience
enum AgeGroup: Equatable {
    case preschool      // 3-5
    case earlySchool    // 6-8
    case middleSchool   // 9-11
    case teen           // 12+
    
    init(age: Int) {
        switch age {
        case 0...5:
            self = .preschool
        case 6...8:
            self = .earlySchool
        case 9...11:
            self = .middleSchool
        default:
            self = .teen
        }
    }
    
    var minAge: Int {
        switch self {
        case .preschool:
            return 3
        case .earlySchool:
            return 6
        case .middleSchool:
            return 9
        case .teen:
            return 12
        }
    }
}
