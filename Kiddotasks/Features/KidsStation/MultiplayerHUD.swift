import SwiftUI

// MARK: - Multiplayer VS HUD

/// Top bar: P1 · VS · P2 with bouncing active avatar.
struct MultiplayerHUD: View {
    let players: [GamePlayer]
    let activeIndex: Int
    var scores: [Int]? = nil
    var turnLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    if index > 0 {
                        Text("VS")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                            .padding(.horizontal, 2)
                    }
                    playerChip(player, index: index)
                }
            }
            if let turnLabel {
                Text(turnLabel)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(KiddoTasksDesignTokens.Colors.primaryLight))
                    .scaleEffect(pulse && !reduceMotion ? 1.05 : 1)
                    .animation(
                        reduceMotion ? .default : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
        }
        .onAppear { pulse = true }
        .onChange(of: activeIndex) { _, _ in
            Haptic.light()
        }
    }

    private func playerChip(_ player: GamePlayer, index: Int) -> some View {
        let isActive = index == activeIndex
        let score = scores?[safe: index] ?? player.score
        return HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: player.colorHex).opacity(isActive ? 0.3 : 0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(player.displayName.prefix(1)))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: player.colorHex))
                )
                .scaleEffect(isActive && !reduceMotion ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isActive)
            VStack(alignment: .leading, spacing: 0) {
                Text(player.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Text("⭐ \(score)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? KiddoTasksDesignTokens.Colors.surfaceCard : KiddoTasksDesignTokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? Color(hex: player.colorHex).opacity(0.55) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Arcade header (inside game cover)

struct ArcadeGameHeader: View {
    let title: String
    let emoji: String
    var onExit: () -> Void

    var body: some View {
        HStack {
            Button {
                GameSounds.restart()
                onExit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                    Text("Arcade")
                }
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.9)))
            }
            .buttonStyle(KiddoPressStyle())
            Spacer()
            Text("\(emoji) \(title)")
                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                .fontWeight(.bold)
            Spacer()
            Color.clear.frame(width: 72, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
