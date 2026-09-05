import SwiftUI

/// The Kiddotasks logo mark: a flat rounded square with a checklist motif.
struct KiddotasksLogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(KiddotasksDesignTokens.Colors.primary)
            // Three small checkmarks — a unique flat motif.
            VStack(alignment: .leading, spacing: size * 0.12) {
                HStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white)
                        .frame(width: size * 0.10, height: size * 0.10)
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white.opacity(0.85))
                        .frame(width: size * 0.40, height: size * 0.10)
                }
                HStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white)
                        .frame(width: size * 0.10, height: size * 0.10)
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white.opacity(0.85))
                        .frame(width: size * 0.30, height: size * 0.10)
                }
                HStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white)
                        .frame(width: size * 0.10, height: size * 0.10)
                    RoundedRectangle(cornerRadius: size * 0.04)
                        .fill(.white.opacity(0.85))
                        .frame(width: size * 0.36, height: size * 0.10)
                }
            }
            .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(
            color: KiddotasksDesignTokens.Colors.primary.opacity(0.25),
            radius: size * 0.10,
            x: 0,
            y: size * 0.06
        )
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
    .kiddoPageBackground(KiddotasksDesignTokens.PageBackgrounds.kidsPlayground)
}
