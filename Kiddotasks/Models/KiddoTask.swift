import Foundation
import Observation

/// A chore / responsibility. Named `KiddoTask` so it does not clash with Swift concurrency `Task`.
@Observable
final class KiddoTask: Identifiable, Codable, Hashable {
    let id: String
    let familyId: String
    var name: String
    var description: String
    var icon: String
    var category: TaskCategory
    var pointValue: Int
    /// Kept for decoding tasks created before approval overrides were added.
    var requiresApproval: Bool
    var approvalBehavior: TaskApprovalBehavior
    var assignedChildIds: [String]
    var recurrence: TaskRecurrence
    var isActive: Bool
    let createdBy: String
    let createdAt: Date
    var updatedAt: Date
    var version: Int

    enum CodingKeys: String, CodingKey {
        case id, familyId, name, description, icon, category, pointValue
        case requiresApproval, approvalBehavior, assignedChildIds, recurrence, isActive
        case createdBy, createdAt, updatedAt, version
    }

    init(
        id: String = UUID().uuidString,
        familyId: String,
        name: String,
        description: String = "",
        icon: String = "checkmark.circle",
        category: TaskCategory = .household,
        pointValue: Int = 10,
        requiresApproval: Bool = true,
        approvalBehavior: TaskApprovalBehavior = .useFamilyDefault,
        assignedChildIds: [String] = [],
        recurrence: TaskRecurrence = .oneTime,
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
        self.category = category
        self.pointValue = pointValue
        self.requiresApproval = requiresApproval
        self.approvalBehavior = approvalBehavior
        self.assignedChildIds = assignedChildIds
        self.recurrence = recurrence
        self.isActive = isActive
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }

    func isAssignedTo(_ childId: String) -> Bool {
        assignedChildIds.isEmpty || assignedChildIds.contains(childId)
    }

    func requiresParentApproval(using settings: FamilySettings) -> Bool {
        switch approvalBehavior {
        case .useFamilyDefault:
            return settings.requireApprovalByDefault
        case .alwaysRequireApproval:
            return true
        case .autoApprove:
            return false
        }
    }

    /// Whether this chore should appear on a given calendar day.
    func isDue(on date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        switch recurrence.type {
        case .oneTime:
            return calendar.isDate(createdAt, inSameDayAs: date) || createdAt <= date
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return weekday != 1 && weekday != 7
        case .weekly:
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: createdAt)
        case .custom:
            return true
        }
    }

    static func == (lhs: KiddoTask, rhs: KiddoTask) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum TaskApprovalBehavior: String, Codable, CaseIterable, Identifiable {
    case useFamilyDefault
    case alwaysRequireApproval
    case autoApprove

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .useFamilyDefault: return "Use family setting"
        case .alwaysRequireApproval: return "Always require approval"
        case .autoApprove: return "Auto-approve and award points"
        }
    }
}

/// The high-level kind of a mission. Raw values are persisted locally and are
/// shared with the Firestore schema.
enum TaskCategory: String, Codable, CaseIterable {
    case household
    case learning
    case health
    case personal
    case pets
    case other

    var displayName: String {
        switch self {
        case .household: return "Household"
        case .learning: return "Learning"
        case .health: return "Health"
        case .personal: return "Personal care"
        case .pets: return "Pet care"
        case .other: return "Other"
        }
    }
}

/// Frequency options shown when a parent creates a mission.
enum RecurrenceType: String, Codable, CaseIterable {
    case oneTime
    case daily
    case weekdays
    case weekly
    case custom

    var displayName: String {
        switch self {
        case .oneTime: return "One time"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

/// Persisted recurrence configuration for a task.
struct TaskRecurrence: Codable, Equatable {
    var type: RecurrenceType
    var weekdays: [Int]?

    init(type: RecurrenceType = .oneTime, weekdays: [Int]? = nil) {
        self.type = type
        self.weekdays = weekdays
    }

    static let oneTime = TaskRecurrence(type: .oneTime)
    static let daily = TaskRecurrence(type: .daily)
    static let weekdays = TaskRecurrence(type: .weekdays)
    static let weekly = TaskRecurrence(type: .weekly)
    static let custom = TaskRecurrence(type: .custom)
}
