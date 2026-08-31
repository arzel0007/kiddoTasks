import SwiftUI

/// Centralized Kiddotasks design tokens
struct KiddotasksDesignTokens {
    // MARK: - Colors
    
    struct Colors {
        // Brand colors
        static let primary = Color(red: 0.388, green: 0.408, blue: 0.949)           // #6366F1 Indigo
        static let accent = Color(red: 0.922, green: 0.286, blue: 0.604)             // #EC4899 Pink
        static let success = Color(red: 0.063, green: 0.725, blue: 0.510)            // #10B981 Green
        static let warning = Color(red: 0.961, green: 0.620, blue: 0.059)            // #F59E0B Amber
        static let error = Color(red: 0.957, green: 0.267, blue: 0.267)              // #EF4444 Red
        
        // Kids-friendly backgrounds
        static let kidsBackground1 = Color(red: 0.996, green: 0.949, blue: 0.781)   // #FEF3C7 Yellow
        static let kidsBackground2 = Color(red: 0.878, green: 0.949, blue: 0.996)   // #E0F2FE Blue
        static let kidsBackground3 = Color(red: 0.862, green: 0.978, blue: 0.945)   // #DCF9F1 Teal
        static let kidsBackground4 = Color(red: 0.993, green: 0.906, blue: 0.953)   // #FCE7F3 Pink
        
        // Neutral colors
        static let text = Color(red: 0.121, green: 0.165, blue: 0.204)               // #1F2937 Gray-800
        static let textSecondary = Color(red: 0.420, green: 0.451, blue: 0.502)     // #6B7280 Gray-500
        static let textTertiary = Color(red: 0.690, green: 0.706, blue: 0.718)      // #B0B4BE Gray-400
        static let background = Color(red: 1.0, green: 1.0, blue: 1.0)               // #FFFFFF White
        static let surface = Color(red: 0.976, green: 0.976, blue: 0.980)            // #F9FAFB Gray-50
        static let border = Color(red: 0.933, green: 0.933, blue: 0.937)             // #EDEDED Gray-100
        
        // Status colors
        static let taskPending = Color(red: 0.961, green: 0.620, blue: 0.059)        // Amber
        static let taskCompleted = Color(red: 0.063, green: 0.725, blue: 0.510)      // Green
        static let taskApproved = Color(red: 0.063, green: 0.725, blue: 0.510)       // Green
        static let taskRejected = Color(red: 0.957, green: 0.267, blue: 0.267)       // Red
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display - Large headings
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .default)
        
        // Heading - Section headers
        static let headingLarge = Font.system(size: 24, weight: .semibold, design: .default)
        static let headingMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let headingSmall = Font.system(size: 18, weight: .semibold, design: .default)
        
        // Title - Card titles
        static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 18, weight: .semibold, design: .default)
        static let titleSmall = Font.system(size: 16, weight: .semibold, design: .default)
        
        // Body - Main text
        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
        
        // Caption - Small supporting text
        static let captionLarge = Font.system(size: 13, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)
        
        // Special - Points and labels
        static let pointsDisplay = Font.system(size: 28, weight: .bold, design: .default)
        static let taskLabel = Font.system(size: 12, weight: .semibold, design: .default)
        static let buttonLabel = Font.system(size: 16, weight: .semibold, design: .default)
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
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
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
    /// Apply Kiddotasks card shadow
    func kiddotasksShadow(_ style: ShadowStyle = .medium) -> some View {
        let shadow = style.shadow
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Apply Kiddotasks corner radius
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
            return KiddotasksDesignTokens.Shadows.small
        case .medium:
            return KiddotasksDesignTokens.Shadows.medium
        case .large:
            return KiddotasksDesignTokens.Shadows.large
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
            return KiddotasksDesignTokens.CornerRadius.small
        case .medium:
            return KiddotasksDesignTokens.CornerRadius.medium
        case .large:
            return KiddotasksDesignTokens.CornerRadius.large
        case .extraLarge:
            return KiddotasksDesignTokens.CornerRadius.extraLarge
        }
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
