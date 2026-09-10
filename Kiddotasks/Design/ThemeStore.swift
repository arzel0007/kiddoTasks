import SwiftUI

/// User-selectable appearance. Night is an intentional dark theme, not an invert.
enum KiddoAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .night: return "Night"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .night: return .dark
        }
    }
}

/// App-wide appearance preference (persisted).
@Observable
@MainActor
final class ThemeStore {
    static let storageKey = "kiddo.appearance"

    var appearance: KiddoAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        appearance = KiddoAppearance(rawValue: raw) ?? .system
    }
}

// MARK: - Semantic surfaces

extension KiddoTasksDesignTokens.Colors {
    /// Dynamic card / elevated surface. Flat fill — no gradients.
    static var surfaceCard: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
                : UIColor.white
        })
    }

    /// Secondary page-level surface (forms, sheets chrome).
    static var surfaceElevated: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
                : UIColor(red: 0.976, green: 0.976, blue: 0.980, alpha: 1)
        })
    }

    /// Hairline borders that read in both modes.
    static var borderSubtle: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.10)
                : UIColor(red: 0.933, green: 0.933, blue: 0.937, alpha: 1)
        })
    }

    /// Primary text (alias kept for call sites that used text).
    static var textPrimary: Color { text }

    /// Soft tint of primary for chips / pressed fills.
    static var primarySoft: Color { primary.opacity(0.12) }
}
