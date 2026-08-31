import Foundation

/// Represents an achievement earned by a child
struct Achievement: Identifiable, Codable {
    let id: String
    let familyId: String
    let childId: String
    let type: AchievementType
    let earnedAt: Date
    var metadata: [String: String] = [:]     // Additional info (e.g., streak count)
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        childId: String,
        type: AchievementType,
        earnedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.familyId = familyId
        self.childId = childId
        self.type = type
        self.earnedAt = earnedAt
        self.metadata = metadata
    }
}

/// Achievement types (lightweight, not overwhelming)
enum AchievementType: String, Codable, CaseIterable {
    case firstTask = "FIRST_TASK"
    case streak3Day = "STREAK_3"
    case streak7Day = "STREAK_7"
    case streak14Day = "STREAK_14"
    case points100 = "POINTS_100"
    case points250 = "POINTS_250"
    case points500 = "POINTS_500"
    case cleaningHero = "CLEANING_HERO"
    case morningHelper = "MORNING_HELPER"
    case responsibleKid = "RESPONSIBLE_KID"
    
    var displayName: String {
        switch self {
        case .firstTask:
            return "First Task"
        case .streak3Day:
            return "3-Day Helper"
        case .streak7Day:
            return "7-Day Helper"
        case .streak14Day:
            return "14-Day Helper"
        case .points100:
            return "100 Points"
        case .points250:
            return "250 Points"
        case .points500:
            return "500 Points"
        case .cleaningHero:
            return "Cleaning Hero"
        case .morningHelper:
            return "Morning Helper"
        case .responsibleKid:
            return "Responsible Kid"
        }
    }
    
    var emoji: String {
        switch self {
        case .firstTask:
            return "🌟"
        case .streak3Day:
            return "🔥"
        case .streak7Day:
            return "🔥🔥"
        case .streak14Day:
            return "🔥🔥🔥"
        case .points100:
            return "⭐"
        case .points250:
            return "⭐⭐"
        case .points500:
            return "⭐⭐⭐"
        case .cleaningHero:
            return "🧹"
        case .morningHelper:
            return "🌅"
        case .responsibleKid:
            return "👑"
        }
    }
    
    var description: String {
        switch self {
        case .firstTask:
            return "Completed your first task!"
        case .streak3Day:
            return "Completed tasks for 3 days in a row!"
        case .streak7Day:
            return "Completed tasks for 7 days in a row!"
        case .streak14Day:
            return "Completed tasks for 14 days in a row!"
        case .points100:
            return "Earned 100 points!"
        case .points250:
            return "Earned 250 points!"
        case .points500:
            return "Earned 500 points!"
        case .cleaningHero:
            return "Completed 10 cleaning tasks!"
        case .morningHelper:
            return "Completed 5 morning tasks!"
        case .responsibleKid:
            return "Maintained responsibility!"
        }
    }
}
