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
    /// Dynamic card / elevated surface. Cool steel-blue tinted, flat fill.
    static var surfaceCard: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.15, blue: 0.20, alpha: 1)
                : UIColor.white
        })
    }

    /// Secondary page-level surface (forms, sheets chrome).
    static var surfaceElevated: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 1)
                : UIColor(red: 0.941, green: 0.953, blue: 0.965, alpha: 1) // #F0F3F6
        })
    }

    /// Hairline borders that read in both modes.
    static var borderSubtle: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.58, green: 0.69, blue: 0.78, alpha: 0.16)
                : UIColor(red: 0.851, green: 0.882, blue: 0.910, alpha: 1) // #D9E1E8
        })
    }

    /// Primary text (alias kept for call sites that used text).
    static var textPrimary: Color { text }

    /// Soft tint of primary for chips / pressed fills.
    static var primarySoft: Color { primary.opacity(0.12) }
}
