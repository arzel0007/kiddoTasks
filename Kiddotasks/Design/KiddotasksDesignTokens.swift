import SwiftUI

/// Centralized KiddoTasks design tokens
struct KiddoTasksDesignTokens {
    // MARK: - Colors
    
    struct Colors {
        // Brand — CALM ADVENTURE
        static let primary = Color(hex: "#3978A8")
        static let primaryDeep = Color(hex: "#285B82")
        static let primaryLight = Color(hex: "#E7F1F8")
        static let primaryMuted = Color(hex: "#6F9FBD")
        static let accent = Color(hex: "#6F9FBD")
        static let success = Color(hex: "#3F8B70")
        static let successLight = Color(hex: "#E8F4EF")
        static let warning = Color(hex: "#D59A3A")   // reward
        static let reward = Color(hex: "#D59A3A")
        static let rewardLight = Color(hex: "#FBF3E3")
        static let error = Color(hex: "#D97868")
        static let attention = Color(hex: "#D97868")
        static let attentionLight = Color(hex: "#FBECEA")

        // Kids backgrounds (cool, restrained)
        static let kidsBackground1 = Color(hex: "#F6F8FA")
        static let kidsBackground2 = Color(hex: "#E7F1F8")
        static let kidsBackground3 = Color(hex: "#E8F4EF")
        static let kidsBackground4 = Color(hex: "#F0F3F6")

        // Neutrals
        static let text = Color(hex: "#24364B")
        static let textSecondary = Color(hex: "#647487")
        static let textTertiary = Color(hex: "#8B99A8")
        static let background = Color(hex: "#FFFFFF")
        static let surface = Color(hex: "#F0F3F6")
        static let border = Color(hex: "#D9E1E8")

        // Status
        static let taskPending = Color(hex: "#D59A3A")
        static let taskCompleted = Color(hex: "#3F8B70")
        static let taskApproved = Color(hex: "#3F8B70")
        static let taskRejected = Color(hex: "#D97868")
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display - Large headings (rounded for a friendly, playful feel)
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .rounded)
        
        // Heading - Section headers
        static let headingLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let headingMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headingSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
        
        // Title - Card titles
        static let titleLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let titleMedium = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let titleSmall = Font.system(size: 16, weight: .semibold, design: .rounded)
        
        // Body - Main text
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
        
        // Caption - Small supporting text
        static let captionLarge = Font.system(size: 13, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)
        
        // Special - Points and labels
        static let pointsDisplay = Font.system(size: 28, weight: .bold, design: .rounded)
        static let taskLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let buttonLabel = Font.system(size: 16, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let extraLarge: CGFloat = 24
        static let full: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let bounce = SwiftUI.Animation.interpolatingSpring(
            mass: 1,
            stiffness: 120,
            damping: 12
        )
    }
    
    // MARK: - Icons
    
    struct Icons {
        static let largeSize: CGFloat = 64
        static let mediumSize: CGFloat = 48
        static let smallSize: CGFloat = 32
        static let tinySize: CGFloat = 24
    }
    
    // MARK: - Touch Targets (Accessibility)
    
    struct TouchTargets {
        static let minimum: CGFloat = 44              // Apple minimum
        static let recommended: CGFloat = 48          // Comfortable for children
        static let large: CGFloat = 56                // Extra comfortable
    }
}

/// Shadow helper struct
struct Shadow: Equatable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers

extension View {
    /// Apply KiddoTasks card shadow
    func kiddotasksShadow(_ style: ShadowStyle = .medium) -> some View {
        let shadow = style.shadow
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Apply KiddoTasks corner radius
    func kiddotasksCornerRadius(_ style: CornerRadiusStyle = .medium) -> some View {
        self.cornerRadius(style.radius, antialiased: true)
    }
}

enum ShadowStyle {
    case small
    case medium
    case large
    
    var shadow: Shadow {
        switch self {
        case .small:
            return KiddoTasksDesignTokens.Shadows.small
        case .medium:
            return KiddoTasksDesignTokens.Shadows.medium
        case .large:
            return KiddoTasksDesignTokens.Shadows.large
        }
    }
}

enum CornerRadiusStyle {
    case small
    case medium
    case large
    case extraLarge
    
    var radius: CGFloat {
        switch self {
        case .small:
            return KiddoTasksDesignTokens.CornerRadius.small
        case .medium:
            return KiddoTasksDesignTokens.CornerRadius.medium
        case .large:
            return KiddoTasksDesignTokens.CornerRadius.large
        case .extraLarge:
            return KiddoTasksDesignTokens.CornerRadius.extraLarge
        }
    }
}

// MARK: - Gradients

extension KiddoTasksDesignTokens {

    /// Flat page background colors that adapt to light/dark mode. Kids screens
    /// stay vivid; the parent side stays calm.
    struct PageBackgrounds {
        /// Cool steel-blue mist for player select / badges.
        static let kidsPlayground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1)
                : UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1)
        })
        static let kidsMissionSky = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 1)
                : UIColor(red: 0.88, green: 0.92, blue: 0.95, alpha: 1)
        })
        static let kidsRewardPop = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1)
                : UIColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1)
        })
        static let parentPage = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1)
                : UIColor(red: 0.965, green: 0.973, blue: 0.980, alpha: 1) // #F6F8FA
        })
        static let welcome = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1)
                : UIColor.white
        })
    }
}

// MARK: - Kids palette & animations

extension KiddoTasksDesignTokens {

    /// Restrained kids accents in the steel-blue family (no loud purple/yellow).
    struct KidsColors {
        static let sunshine = Color(hex: "#D59A3A")
        static let bubblegum = Color(hex: "#6F9FBD")
        static let ocean = Color(hex: "#3978A8")
        static let lime = Color(hex: "#3F8B70")
        static let grape = Color(hex: "#6B8A9E")
        static let coral = Color(hex: "#B87A5A")
        static let mint = Color(hex: "#3D8B6E")
        static let strawberry = Color(hex: "#C25A5A")
        static let sky = Color(hex: "#6A9BC3")
        static let lavender = Color(hex: "#8FA8BC")
        static let peach = Color(hex: "#C4A574")
    }

    /// Spring animations tuned for playful micro-interactions.
    struct KidsAnimations {
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.5)
        static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.6)
        static let slowBounce = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.4)
    }
}

// MARK: - Category theming

/// A color pair used to theme cards and icon tiles — flat, no gradients.
struct KiddoThemePalette {
    let accent: Color
    let soft: Color

    init(accent: Color) {
        self.accent = accent
        self.soft = accent.opacity(0.14)
    }
}

extension TaskCategory {
    var palette: KiddoThemePalette {
        switch self {
        case .household:
            return KiddoThemePalette(accent: Color(hex: "#3978A8"))
        case .learning:
            return KiddoThemePalette(accent: Color(hex: "#6F9FBD"))
        case .health:
            return KiddoThemePalette(accent: Color(hex: "#3F8B70"))
        case .personal:
            return KiddoThemePalette(accent: Color(hex: "#D59A3A"))
        case .pets:
            return KiddoThemePalette(accent: Color(hex: "#8B99A8"))
        case .other:
            return KiddoThemePalette(accent: Color(hex: "#647487"))
        }
    }
}

// MARK: - Page background modifier

/// Paints a flat color behind the safe areas so lists and cards float on it.
struct KiddoPageBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .background(color)
    }
}

extension View {
    func kiddoPageBackground(_ color: Color) -> some View {
        modifier(KiddoPageBackgroundModifier(color: color))
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (99, 102, 241)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
