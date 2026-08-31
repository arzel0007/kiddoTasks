import Foundation
import Observation

/// Represents a task completion record
@Observable
final class TaskCompletion: Identifiable, Codable {
    let id: String
    let familyId: String
    let taskId: String
    let childId: String
    var status: CompletionStatus
    let completedAt: Date
    var approvedAt: Date?
    var approvedBy: String?                // Parent ID
    var pointsAwarded: Int?
    var pointTransactionId: String?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case taskId
        case childId
        case status
        case completedAt
        case approvedAt
        case approvedBy
        case pointsAwarded
        case pointTransactionId
        case notes
    }
    
    init(
        id: String = UUID().uuidString,
        familyId: String,
        taskId: String,
        childId: String,
        status: CompletionStatus = .completed,
        completedAt: Date = Date(),
        approvedAt: Date? = nil,
        approvedBy: String? = nil,
        pointsAwarded: Int? = nil,
        pointTransactionId: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.taskId = taskId
        self.childId = childId
        self.status = status
        self.completedAt = completedAt
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.pointsAwarded = pointsAwarded
        self.pointTransactionId = pointTransactionId
        self.notes = notes
    }
    
    /// Check if completion is finalized (points awarded)
    var isFinalized: Bool {
        status == .approved && pointsAwarded != nil
    }
    
    /// Check if awaiting parent action
    var isPending: Bool {
        status == .awaitingApproval
    }
}

/// Completion status lifecycle
enum CompletionStatus: String, Codable {
    case completed = "COMPLETED"              // Just submitted
    case awaitingApproval = "AWAITING_APPROVAL"
    case approved = "APPROVED"                // Approved, points awarded
    case rejected = "REJECTED"                // Parent rejected
    
    var displayName: String {
        switch self {
        case .completed:
            return "Submitted"
        case .awaitingApproval:
            return "Waiting for approval"
        case .approved:
            return "Approved ✓"
        case .rejected:
            return "Needs revision"
        }
    }
    
    var isFinished: Bool {
        self == .approved || self == .rejected
    }
    
    var isPending: Bool {
        self == .awaitingApproval
    }
}
