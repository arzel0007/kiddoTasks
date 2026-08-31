import SwiftUI

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
                .background(isDisabled ? color.opacity(0.4) : color)
                .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.medium))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

struct ChildAvatarView: View {
    let avatar: ChildAvatar
    var size: CGFloat = 64

    var body: some View {
        Text(avatar.emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(Color(hex: avatar.colorHex).opacity(0.35))
            .clipShape(Circle())
    }
}

struct PointsBadge: View {
    let points: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text("⭐")
            Text("\(points)")
                .font(compact ? KiddotasksDesignTokens.Typography.titleSmall : KiddotasksDesignTokens.Typography.pointsDisplay)
        }
        .foregroundStyle(KiddotasksDesignTokens.Colors.text)
    }
}

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 56))
            Text(title).font(KiddotasksDesignTokens.Typography.headingMedium)
            Text(message)
                .font(KiddotasksDesignTokens.Typography.bodyMedium)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MissionCard: View {
    let task: KiddoTask
    let completion: TaskCompletion?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: task.icon)
                .font(.title2)
                .foregroundStyle(KiddotasksDesignTokens.Colors.primary)
                .frame(width: 48, height: 48)
                .background(KiddotasksDesignTokens.Colors.kidsBackground2)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                Text(statusText)
                    .font(KiddotasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            Text("+\(task.pointValue)")
                .font(KiddotasksDesignTokens.Typography.titleSmall)
                .foregroundStyle(KiddotasksDesignTokens.Colors.success)
        }
        .padding()
        .background(KiddotasksDesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.large))
        .kiddotasksShadow(.small)
        .opacity(completion?.status == .approved ? 0.55 : 1)
    }

    private var statusText: String {
        completion?.status.displayName ?? task.category.displayName
    }

    private var statusColor: Color {
        switch completion?.status {
        case .approved: return KiddotasksDesignTokens.Colors.success
        case .awaitingApproval, .completed: return KiddotasksDesignTokens.Colors.warning
        case .rejected: return KiddotasksDesignTokens.Colors.error
        case .none: return KiddotasksDesignTokens.Colors.textSecondary
        }
    }
}

struct RewardShopCard: View {
    let reward: Reward
    let points: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: reward.icon)
                .font(.title)
                .foregroundStyle(KiddotasksDesignTokens.Colors.accent)
            Text(reward.name)
                .font(KiddotasksDesignTokens.Typography.titleSmall)
            Text(reward.description)
                .font(KiddotasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                Text("\(reward.pointCost) ⭐")
                    .font(KiddotasksDesignTokens.Typography.titleSmall)
                Spacer()
                if reward.canAfford(with: points) {
                    Text("Get")
                        .font(KiddotasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.success)
                } else {
                    Text("Need \(reward.pointsNeeded(givenCurrentPoints: points))")
                        .font(KiddotasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(KiddotasksDesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: KiddotasksDesignTokens.CornerRadius.large))
        .kiddotasksShadow(.small)
    }
}
