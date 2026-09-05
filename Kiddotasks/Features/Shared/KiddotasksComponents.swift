import SwiftUI

// MARK: - Button styles

/// Adds a springy press animation to any button.
struct KiddoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var color: Color = KiddotasksDesignTokens.Colors.primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KiddotasksDesignTokens.Typography.buttonLabel)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KiddotasksDesignTokens.TouchTargets.recommended)
                .background {
                    let shape = RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.medium, style: .continuous)
                    if isDisabled {
                        shape.fill(color.opacity(0.35))
                    } else {
                        shape.fill(color)
                    }
                }
        }
        .disabled(isDisabled)
        .buttonStyle(KiddoPressStyle())
    }
}

// MARK: - SecondaryButton

/// Outlined button for secondary actions.
struct SecondaryButton: View {
    let title: String
    var color: Color = KiddotasksDesignTokens.Colors.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KiddotasksDesignTokens.Typography.buttonLabel)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KiddotasksDesignTokens.TouchTargets.recommended)
                .background(color.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(color.opacity(0.45), lineWidth: 1.5)
                }
        }
        .buttonStyle(KiddoPressStyle())
    }
}

// MARK: - Avatars & points

struct ChildAvatarView: View {
    let avatar: ChildAvatar
    var size: CGFloat = 64

    var body: some View {
        Text(avatar.emoji)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background {
                Circle().fill(Color(hex: avatar.colorHex).opacity(0.28))
            }
            .overlay {
                Circle().strokeBorder(.white, lineWidth: max(1.5, size * 0.055))
            }
            .shadow(color: Color(hex: avatar.colorHex).opacity(0.30), radius: size * 0.14, x: 0, y: size * 0.08)
    }
}

struct PointsBadge: View {
    let points: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: compact ? 10 : 13, weight: .bold))
            Text("\(points)")
                .font(compact ? KiddotasksDesignTokens.Typography.captionLarge : KiddotasksDesignTokens.Typography.titleSmall)
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(Color(hex: "#F59E0B")))
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 52))
                .frame(width: 96, height: 96)
                .background(Circle().fill(.white))
                .kiddotasksShadow(.medium)
            Text(title).font(KiddotasksDesignTokens.Typography.headingMedium)
            Text(message)
                .font(KiddotasksDesignTokens.Typography.bodyMedium)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cards

/// White rounded container used across the Parent Center.
struct SectionCard<Content: View>: View {
    let title: String
    var icon: String = "sparkles"
    var tint: Color = KiddotasksDesignTokens.Colors.primary
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KiddotasksDesignTokens.Spacing.small) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
            }
            content
        }
        .padding(KiddotasksDesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.large, style: .continuous))
        .kiddotasksShadow(.medium)
    }
}

/// A compact metric tile for the Today dashboard.
struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    var shadowColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("\(value)")
                .font(KiddotasksDesignTokens.Typography.displaySmall)
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(KiddotasksDesignTokens.Typography.taskLabel)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2, reservesSpace: true)
        }
        .padding(KiddotasksDesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.large, style: .continuous)
                .fill(color)
        }
    }
}

// MARK: - Mission card (kids)

struct MissionCard: View {
    let task: KiddoTask
    let completion: TaskCompletion?

    private var palette: KiddoThemePalette { task.category.palette }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: task.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddotasksDesignTokens.Colors.text)
                StatusChip(status: completion?.status, fallback: task.category.displayName)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(task.pointValue)")
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                    .monospacedDigit()
            }
            .foregroundStyle(Color(hex: "#B45309"))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: "#FEF3C7")))
        }
        .padding(KiddotasksDesignTokens.Spacing.medium)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.extraLarge, style: .continuous))
        .kiddotasksShadow(.medium)
        .opacity(completion?.status == .approved ? 0.6 : 1)
    }
}

/// Small rounded status label used on mission cards.
struct StatusChip: View {
    let status: CompletionStatus?
    var fallback: String

    var body: some View {
        Text(text)
            .font(KiddotasksDesignTokens.Typography.captionSmall)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private var text: String {
        status?.displayName ?? fallback
    }

    private var color: Color {
        switch status {
        case .approved: return KiddotasksDesignTokens.Colors.success
        case .awaitingApproval, .completed: return KiddotasksDesignTokens.Colors.warning
        case .rejected: return KiddotasksDesignTokens.Colors.error
        case .none: return KiddotasksDesignTokens.Colors.textSecondary
        }
    }
}

// MARK: - Reward shop card (kids)

struct RewardShopCard: View {
    let reward: Reward
    let points: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: reward.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(KiddotasksDesignTokens.Colors.accent)
                }
            Text(reward.name)
                .font(KiddotasksDesignTokens.Typography.titleSmall)
                .foregroundStyle(KiddotasksDesignTokens.Colors.text)
            Text(reward.description)
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(reward.pointCost)")
                        .monospacedDigit()
                }
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(Color(hex: "#B45309"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "#FEF3C7")))
                Spacer()
                if reward.canAfford(with: points) {
                    Text("Get")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(KiddotasksDesignTokens.Colors.success))
                } else {
                    Text("Need \(reward.pointsNeeded(givenCurrentPoints: points))")
                        .font(KiddotasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding(KiddotasksDesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.extraLarge, style: .continuous))
        .kiddotasksShadow(.medium)
    }
}
