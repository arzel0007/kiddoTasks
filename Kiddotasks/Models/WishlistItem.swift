import Foundation
import Observation

/// A child's gift wish — completely separate from the points/rewards economy.
/// Reviewing a wishlist item NEVER awards or deducts points.
@Observable
final class WishlistItem: Identifiable, Codable {
    let id: String
    let familyId: String
    let childId: String
    var title: String
    var message: String
    var occasion: WishlistOccasion?
    var status: WishlistStatus
    var parentResponse: String?
    let createdBy: String
    let createdAt: Date
    var updatedAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?
    var version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case familyId
        case childId
        case title
        case message
        case occasion
        case status
        case parentResponse
        case createdBy
        case createdAt
        case updatedAt
        case reviewedAt
        case reviewedBy
        case version
    }

    init(
        id: String = UUID().uuidString,
        familyId: String,
        childId: String,
        title: String,
        message: String = "",
        occasion: WishlistOccasion? = nil,
        status: WishlistStatus = .pending,
        parentResponse: String? = nil,
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.familyId = familyId
        self.childId = childId
        self.title = title
        self.message = message
        self.occasion = occasion
        self.status = status
        self.parentResponse = parentResponse
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.version = version
    }

    /// Kid may edit only while still waiting for a parent decision.
    var isEditableByChild: Bool {
        status == .pending
    }

    /// Kid may delete waiting or rejected items (mirrors cloud rules).
    var isDeletableByChild: Bool {
        status == .pending || status == .rejected
    }

    var isPending: Bool {
        status == .pending
    }

    var hasParentResponse: Bool {
        guard let parentResponse else { return false }
        return !parentResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// Explicit Codable for @Observable models (same pattern as Reward/Child).
extension WishlistItem {
    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            familyId: try c.decode(String.self, forKey: .familyId),
            childId: try c.decode(String.self, forKey: .childId),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "",
            message: try c.decodeIfPresent(String.self, forKey: .message) ?? "",
            occasion: try c.decodeIfPresent(WishlistOccasion.self, forKey: .occasion),
            status: try c.decodeIfPresent(WishlistStatus.self, forKey: .status) ?? .pending,
            parentResponse: try c.decodeIfPresent(String.self, forKey: .parentResponse),
            createdBy: try c.decodeIfPresent(String.self, forKey: .createdBy) ?? "",
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(),
            reviewedAt: try c.decodeIfPresent(Date.self, forKey: .reviewedAt),
            reviewedBy: try c.decodeIfPresent(String.self, forKey: .reviewedBy),
            version: try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encode(childId, forKey: .childId)
        try c.encode(title, forKey: .title)
        try c.encode(message, forKey: .message)
        try c.encodeIfPresent(occasion, forKey: .occasion)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(parentResponse, forKey: .parentResponse)
        try c.encode(createdBy, forKey: .createdBy)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(reviewedAt, forKey: .reviewedAt)
        try c.encodeIfPresent(reviewedBy, forKey: .reviewedBy)
        try c.encode(version, forKey: .version)
    }
}

/// Wishlist review lifecycle. `RECEIVED` exists in the model for future /
/// server-written states; the parent review callable only sets APPROVED or
/// REJECTED.
enum WishlistStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case received = "RECEIVED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Waiting"
        case .approved:
            return "Approved"
        case .rejected:
            return "Not now"
        case .received:
            return "Received"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "hourglass"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .received:
            return "gift.fill"
        }
    }

    var isPending: Bool { self == .pending }
}

/// Gift occasion tags — same raw values as Cloud Functions / web.
enum WishlistOccasion: String, Codable, CaseIterable, Identifiable {
    case birthday = "BIRTHDAY"
    case christmas = "CHRISTMAS"
    case graduation = "GRADUATION"
    case school = "SCHOOL"
    case special = "SPECIAL"
    case justBecause = "JUST_BECAUSE"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .birthday:
            return "Birthday"
        case .christmas:
            return "Christmas"
        case .graduation:
            return "Graduation"
        case .school:
            return "School"
        case .special:
            return "Special"
        case .justBecause:
            return "Just because"
        case .other:
            return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .birthday:
            return "🎂"
        case .christmas:
            return "🎄"
        case .graduation:
            return "🎓"
        case .school:
            return "🎒"
        case .special:
            return "✨"
        case .justBecause:
            return "💛"
        case .other:
            return "🎁"
        }
    }

    /// Parses a raw server/contract string into an occasion (nil when absent/unknown).
    static func from(raw: String?) -> WishlistOccasion? {
        guard let raw, !raw.isEmpty else { return nil }
        return WishlistOccasion(rawValue: raw)
    }
}
