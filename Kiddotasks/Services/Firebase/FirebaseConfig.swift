import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

/// Centralized Firebase configuration and initialization
struct FirebaseConfig {

    static func configure() {
        FirebaseApp.configure()
        configureFirestore()
    }

    private static func configureFirestore() {
        let db = Firestore.firestore()
        var settings = db.settings
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 10 * 1024 * 1024
        db.settings = settings
    }

    static var db: Firestore {
        Firestore.firestore()
    }

    static var auth: Auth {
        Auth.auth()
    }
}
#endif

/// Errors related to store operations
enum FirebaseError: LocalizedError {
    case authNotAvailable
    case notAuthenticated
    case invalidFamily
    case invalidChild
    case invalidTask
    case invalidReward
    case permissionDenied
    case documentNotFound
    case operationFailed(String)
    case insufficientPoints
    case invalidCredentials
    case alreadyExists

    var errorDescription: String? {
        switch self {
        case .authNotAvailable:
            return "Authentication is not available"
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidFamily:
            return "Invalid family"
        case .invalidChild:
            return "Invalid child"
        case .invalidTask:
            return "Invalid task"
        case .invalidReward:
            return "Invalid reward"
        case .permissionDenied:
            return "You don't have permission to perform this action"
        case .documentNotFound:
            return "Document not found"
        case .operationFailed(let message):
            return message
        case .insufficientPoints:
            return "Not enough points yet"
        case .invalidCredentials:
            return "Email or password is incorrect"
        case .alreadyExists:
            return "This account already exists"
        }
    }
}

/// Collection names shared by local and cloud stores
struct FirestoreCollections {
    static let families = "families"
    static let parents = "parents"
    static let children = "children"
    static let tasks = "tasks"
    static let taskCompletions = "taskCompletions"
    static let rewards = "rewards"
    static let rewardClaims = "rewardClaims"
    static let pointTransactions = "pointTransactions"
    static let achievements = "achievements"
}
