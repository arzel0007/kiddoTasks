import Foundation

/// Facial expressions Arz can display.
enum ArzExpression: String, CaseIterable, Sendable, Identifiable {
    case idle
    case happy
    case excited
    case laughing
    case wink
    case surprised
    case thinking
    case determined
    case encouraging
    case sad
    case sleepy

    var id: String { rawValue }

    /// Asset catalog image name for this expression.
    var assetName: String {
        switch self {
        case .idle: return "kiddo_head_happy"
        case .happy: return "kiddo_head_happy"
        case .excited: return "kiddo_head_laughing"
        case .laughing: return "kiddo_head_laughing"
        case .wink: return "kiddo_head_wink"
        case .surprised: return "kiddo_head_surprised"
        case .thinking: return "kiddo_head_thinking"
        case .determined: return "kiddo_head_determined"
        case .encouraging: return "kiddo_head_encouraging"
        case .sad: return "kiddo_head_sad"
        case .sleepy: return "kiddo_head_sleepy"
        }
    }

    /// Blink intermediate frame (half-closed eyes).
    var blinkAssetName: String { "kiddo_head_sleepy" }

    var isSticky: Bool {
        switch self {
        case .idle, .thinking, .sleepy: return true
        default: return false
        }
    }

    var holdDuration: TimeInterval {
        switch self {
        case .idle: return .infinity
        case .thinking: return 6
        case .sleepy: return 8
        case .excited, .laughing: return 2.2
        case .surprised: return 1.6
        case .wink: return 1.4
        case .happy, .encouraging, .determined: return 1.8
        case .sad: return 2.4
        }
    }

    var priority: Int {
        switch self {
        case .idle: return 0
        case .happy, .wink: return 1
        case .encouraging, .determined, .sleepy: return 2
        case .sad, .surprised: return 3
        case .laughing, .thinking: return 4
        case .excited: return 5
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle: return "Arz is here"
        case .happy: return "Arz looks happy"
        case .excited: return "Arz looks excited"
        case .laughing: return "Arz is laughing"
        case .wink: return "Arz winks"
        case .surprised: return "Arz looks surprised"
        case .thinking: return "Arz is thinking"
        case .determined: return "Arz looks determined"
        case .encouraging: return "Arz is encouraging you"
        case .sad: return "Arz looks sad"
        case .sleepy: return "Arz looks sleepy"
        }
    }

    static func from(playName: String) -> ArzExpression? {
        ArzExpression(rawValue: playName.lowercased())
    }
}
