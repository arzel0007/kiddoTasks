import Foundation

/// Shared plan rules (mirrors web `lib/entitlements.ts`).
enum KiddoPlan {
    /// Owner / founder account — full access, never paywalled.
    static let ownerEmails: Set<String> = [
        "xxarzelxx@gmail.com",
    ]

    static let freeMaxChildren = 1
    static let freeMaxTasks = 20
    static let premiumPriceDisplay = "₱199/mo"

    static func isOwner(email: String?) -> Bool {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else { return false }
        return ownerEmails.contains(email)
    }

    /// Co-parent join with family code is Premium-only (owner exempt).
    static func canJoinWithCode(email: String?, isPremium: Bool) -> Bool {
        isOwner(email: email) || isPremium
    }

    static func canAddChild(currentCount: Int, email: String?, isPremium: Bool) -> Bool {
        if isOwner(email: email) || isPremium { return true }
        return currentCount < freeMaxChildren
    }

    static func canAddTask(currentCount: Int, email: String?, isPremium: Bool) -> Bool {
        if isOwner(email: email) || isPremium { return true }
        return currentCount < freeMaxTasks
    }

    static func upgradePrompt(for reason: Reason) -> String {
        switch reason {
        case .joinFamily:
            return "Joining another parent’s family with a code is Premium (\(premiumPriceDisplay))."
        case .moreKids:
            return "Free plan includes \(freeMaxChildren) kid. Upgrade to Premium for unlimited kids."
        case .moreTasks:
            return "Free plan includes \(freeMaxTasks) chores. Upgrade to Premium for unlimited chores."
        }
    }

    enum Reason {
        case joinFamily
        case moreKids
        case moreTasks
    }
}

/// How the family tallies allowance-style rewards (in addition to star points).
enum AllowanceMode: String, Codable, CaseIterable, Identifiable {
    /// Stars only (default product behavior).
    case starsOnly = "STARS_ONLY"
    /// Flat amount for any day with at least one approved completion.
    case flatDaily = "FLAT_DAILY"
    /// Sum of each chore’s star/point value treated as cash units.
    case perChore = "PER_CHORE"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .starsOnly: return "Stars only"
        case .flatDaily: return "Flat daily rate"
        case .perChore: return "Per chore"
        }
    }
}
