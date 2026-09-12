import SwiftUI

/// The KiddoTasks logo mark: uses the custom app icon image, scalable to any size.
struct KiddoTasksLogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: size * 0.08, x: 0, y: size * 0.04)
            .accessibilityLabel("KiddoTasks logo")
    }
}

/// Logo mark + wordmark, with an optional tagline.
struct KiddoTasksWordmark: View {
    var size: CGFloat = 44
    var showsTagline = false

    var body: some View {
        VStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
            HStack(spacing: size * 0.24) {
                KiddoTasksLogoMark(size: size)
                Text("KiddoTasks")
                    .font(.system(size: size * 0.50, weight: .heavy, design: .rounded))
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            }
            if showsTagline {
                Text("Missions for kids. Support for parents.")
                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
        }
    }
}

/// Branded header for the Parent Center: logo + brand line + family name.
struct FamilyBrandHeader<Trailing: View>: View {
    let familyName: String
    var subtitle: String?
    var familyPhotoData: Data?
    let trailing: Trailing

    init(
        familyName: String,
        subtitle: String? = nil,
        familyPhotoData: Data? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.familyName = familyName
        self.subtitle = subtitle
        self.familyPhotoData = familyPhotoData
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
            Group {
                if let familyPhotoData, let uiImage = KiddoImageCache.image(from: familyPhotoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    KiddoTasksLogoMark(size: 44)
                }
            }
            VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.xSmall) {
                Text("KIDDOTASKS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                Text(familyName)
                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        KiddoTasksLogoMark(size: 96)
        KiddoTasksWordmark(size: 48, showsTagline: true)
        FamilyBrandHeader(familyName: "The Resurreccions", subtitle: "Tuesday, Sep 8") {
            Image(systemName: "chevron.right")
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding(24)
    .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
}
