import Foundation

/// A notification-worthy family event detected by diffing consecutive cloud
/// snapshots. Pure value type so the diffing logic is unit-testable without
/// touching `UNUserNotificationCenter`.
struct FamilyChangeEvent: Equatable {
    enum Kind: String, Equatable {
        case taskSubmitted        // kid submitted → awaiting approval (parents care most)
        case taskAutoCompleted    // kid finished, no approval needed
        case taskApproved
        case taskRejected
        case rewardClaimed        // kid requested a reward (parents care most)
        case rewardApproved
        case rewardRejected
        case pointsAdjusted       // manual adjust / bonus / reversal
        case miniGamePlayed       // kid finished a mini-game match
    }

    let kind: Kind
    let childName: String
    let detail: String           // task name, reward name, or points description
    let extra: String?           // e.g. point cost, delta, rejection reason

    var title: String {
        switch kind {
        case .taskSubmitted: return "Task awaiting approval"
        case .taskAutoCompleted: return "Task completed"
        case .taskApproved: return "Task approved"
        case .taskRejected: return "Task needs another try"
        case .rewardClaimed: return "Reward requested"
        case .rewardApproved: return "Reward approved 🎉"
        case .rewardRejected: return "Reward not approved"
        case .pointsAdjusted: return "Points updated"
        case .miniGamePlayed: return "Mini-game finished"
        }
    }

    var body: String {
        switch kind {
        case .taskSubmitted:
            return "\(childName) finished “\(detail)” — tap to review"
        case .taskAutoCompleted:
            return "\(childName) completed “\(detail)”" + (extra.map { " \($0)" } ?? "")
        case .taskApproved:
            return "“\(detail)” approved for \(childName)" + (extra.map { " \($0)" } ?? "")
        case .taskRejected:
            return "“\(detail)” needs another try" + (extra.map { " — \($0)" } ?? "")
        case .rewardClaimed:
            return "\(childName) wants “\(detail)”" + (extra.map { " (\($0))" } ?? "")
        case .rewardApproved:
            return "“\(detail)” approved for \(childName) 🎉"
        case .rewardRejected:
            return "“\(detail)” was not approved" + (extra.map { " — \($0)" } ?? "")
        case .pointsAdjusted:
            return detail
        case .miniGamePlayed:
            // childName = who played (may be "Alex & Sam"); detail = game; extra = scores + winner
            if let extra, !extra.isEmpty {
                return "\(childName) played \(detail) — \(extra)"
            }
            return "\(childName) played \(detail)"
        }
    }
}
