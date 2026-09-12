import SwiftUI

/// Controlled player theming for the Kids Station. Accent comes from the
/// child's avatar color; page fills stay inside the Kiddotasks palette
/// (flat fills only — no gradients).
struct ChildPlayerTheme {
    let accent: Color
    let pageBackground: Color
    let cardTint: Color
    let ringColor: Color

    init(colorHex: String, colorScheme: ColorScheme = .light) {
        let accent = Color(hex: colorHex)
        self.accent = accent

        // Keep the page recognizable as Kids Station, with a soft wash of the child.
        let playground = colorScheme == .dark
            ? Color(red: 0.20, green: 0.15, blue: 0.05)
            : Color(red: 0.996, green: 0.949, blue: 0.781)

        // Layered flat tints (not a gradient): playground base + accent wash.
        self.pageBackground = playground
        self.cardTint = accent.opacity(colorScheme == .dark ? 0.18 : 0.12)
        self.ringColor = accent.opacity(colorScheme == .dark ? 0.55 : 0.35)
    }

    static func theme(for child: Child?, colorScheme: ColorScheme) -> ChildPlayerTheme {
        ChildPlayerTheme(colorHex: child?.avatar.colorHex ?? "#3978A8", colorScheme: colorScheme)
    }
}

extension Child {
    var playerAccentColor: Color {
        Color(hex: avatar.colorHex)
    }

    /// Flat page fill for this child's Kids Station screens.
    func playerPageBackground(colorScheme: ColorScheme) -> Color {
        ChildPlayerTheme(colorHex: avatar.colorHex, colorScheme: colorScheme).pageBackground
    }

    /// Soft card wash using the child's accent.
    func playerCardWash(colorScheme: ColorScheme) -> Color {
        Color(hex: avatar.colorHex).opacity(colorScheme == .dark ? 0.22 : 0.14)
    }
}

/// Page background that layers a solid base + optional accent wash.
/// Uses two flat fills (no LinearGradient).
struct ChildPlayerPageBackground: View {
    let child: Child?
    var base: Color = KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            base
            if let child {
                Color(hex: child.avatar.colorHex)
                    .opacity(colorScheme == .dark ? 0.20 : 0.16)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Kids Station page fill tinted by the active child (flat layers only).
    func kiddoChildPageBackground(
        _ child: Child?,
        base: Color = KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky
    ) -> some View {
        background(ChildPlayerPageBackground(child: child, base: base))
    }
}
