import Foundation
import Observation

/// Represents a parent/guardian in Kiddotasks
@Observable
final class Parent: Identifiable, Codable {
    let id: String
    let email: String
    var displayName: String
    let familyId: String
    var role: ParentRole
    let createdAt: Date
    var lastSignInAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case familyId
        case role
        case createdAt
        case lastSignInAt
    }
    
    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        familyId: String,
        role: ParentRole = .manager,
        createdAt: Date = Date(),
        lastSignInAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.familyId = familyId
        self.role = role
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}

/// Parent role in family
enum ParentRole: String, Codable, CaseIterable {
    case owner = "owner"      // Can manage family, all settings
    case manager = "manager"  // Can manage tasks and approve
    
    var description: String {
        switch self {
        case .owner:
            return "Owner"
        case .manager:
            return "Manager"
        }
    }
    
    var isOwner: Bool { self == .owner }
}
