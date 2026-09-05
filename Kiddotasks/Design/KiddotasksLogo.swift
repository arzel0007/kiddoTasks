import SwiftUI

/// The Kiddotasks logo mark: a gradient rounded square with a star.
struct KiddotasksLogoMark: View {
    var size: CGFloat = 64
    var gradient: LinearGradient = KiddotasksDesignTokens.Gradients.hero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(gradient)
                .shadow(
                    color: KiddotasksDesignTokens.Colors.primary.opacity(0.35),
                    radius: size * 0.14,
                    x: 0,
                    y: size * 0.09
                )
            Circle()
                .fill(.white.opacity(0.20))
                .frame(width: size * 0.74, height: size * 0.74)
                .offset(x: -size * 0.07, y: -size * 0.11)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: size * 0.03, x: 0, y: size * 0.03)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Kiddotasks logo")
    }
}

/// Logo mark + wordmark, with an optional tagline.
struct KiddotasksWordmark: View {
    var size: CGFloat = 44
    var showsTagline = false

    var body: some View {
        VStack(spacing: KiddotasksDesignTokens.Spacing.small) {
            HStack(spacing: size * 0.24) {
                KiddotasksLogoMark(size: size)
                Text("Kiddotasks")
                    .font(.system(size: size * 0.58, weight: .heavy, design: .rounded))
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
            }
            if showsTagline {
                Text("Missions for kids. Control for parents.")
                    .font(KiddotasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
            }
        }
    }
}

/// Branded header for the Parent Center: logo + brand line + family name.
struct FamilyBrandHeader<Trailing: View>: View {
    let familyName: String
    var subtitle: String?
    let trailing: Trailing

    init(
        familyName: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.familyName = familyName
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: KiddotasksDesignTokens.Spacing.small) {
            KiddotasksLogoMark(size: 44)
            VStack(alignment: .leading, spacing: KiddotasksDesignTokens.Spacing.xSmall) {
                Text("KIDDOTASKS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.textTertiary)
                Text(familyName)
                    .font(KiddotasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        KiddotasksLogoMark(size: 96)
        KiddotasksWordmark(size: 48, showsTagline: true)
        FamilyBrandHeader(familyName: "The Resurreccions", subtitle: "Tuesday, Sep 8") {
            Image(systemName: "chevron.right")
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding(24)
    .kiddoPageBackground(KiddotasksDesignTokens.Gradients.kidsPlayground)
}
