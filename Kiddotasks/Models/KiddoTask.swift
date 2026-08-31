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
    var requiresApproval: Bool
    var assignedChildIds: [String]
    var recurrence: TaskRecurrence
    var isActive: Bool
    let createdBy: String
    let createdAt: Date
    var updatedAt: Date
    var version: Int

    enum CodingKeys: String, CodingKey {
        case id, familyId, name, description, icon, category, pointValue
        case requiresApproval, assignedChildIds, recurrence, isActive
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
