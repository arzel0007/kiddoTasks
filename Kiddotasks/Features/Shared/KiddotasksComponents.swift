import SwiftUI

// MARK: - Button styles

/// Adds a springy press animation to any button.
struct KiddoPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1 : 0.96) : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                reduceMotion ? .easeInOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

/// Deeper press for parent-facing cards and list chrome.
struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1 : 0.985) : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                reduceMotion ? .easeInOut(duration: 0.1) : .spring(response: 0.28, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

// MARK: - Extra bouncy press style

/// A more dramatic press animation for kid-facing buttons — bigger scale
/// plus a slight rotation that snaps back with a springy overshoot.
struct ExtraBouncyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1 : 0.90) : 1)
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? -3 : 0))
            .animation(
                reduceMotion ? .easeInOut(duration: 0.12) : KiddoTasksDesignTokens.KidsAnimations.bouncy,
                value: configuration.isPressed
            )
    }
}

// MARK: - Floating emoji

/// An emoji that gently bobs up and down forever. Used in empty states
/// and as decorative flourishes so the screen never feels static.
/// Respects Reduce Motion (static when enabled).
struct FloatingEmoji: View {
    let emoji: String
    var size: CGFloat = 56
    var duration: Double = 2.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .offset(y: reduceMotion ? 0 : (isFloating ? -12 : 12))
            .animation(
                reduceMotion
                    ? .default
                    : .easeInOut(duration: duration).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear { if !reduceMotion { isFloating = true } }
    }
}

// MARK: - Celebration burst

/// A burst of emoji particles that radiate outward and fade. Trigger by
/// toggling `trigger` — the animation plays once each time it flips true.
struct CelebrationBurst: View {
    let emojis: [String]
    var trigger: Bool

    @State private var particles: [CelebrationParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(particle.emoji)
                    .font(.system(size: particle.size))
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            if newValue { burst() }
        }
    }

    private func burst() {
        particles = (0..<12).map { i in
            CelebrationParticle(
                emoji: emojis.randomElement() ?? "⭐",
                angle: Double(i) * 30,
                distance: Double.random(in: 60...140)
            )
        }
        withAnimation(.easeOut(duration: 0.8)) {
            for i in particles.indices {
                let dx = CGFloat(cos(particles[i].angle * .pi / 180) * particles[i].distance)
                let dy = CGFloat(sin(particles[i].angle * .pi / 180) * particles[i].distance)
                particles[i].position = CGPoint(
                    x: particles[i].position.x + dx,
                    y: particles[i].position.y + dy
                )
                particles[i].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            particles = []
        }
    }
}

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let angle: Double
    let distance: Double
    var position: CGPoint = .zero
    var opacity: Double = 1
    var size: CGFloat = 28
}

// MARK: - Pop-in modifier

/// Scales a view in with a bounce when it first appears. Use on cards and
/// badges so the screen feels alive as content loads.
struct PopInModifier: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : (reduceMotion ? 1 : 0.92))
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(
                    reduceMotion
                        ? .easeInOut(duration: 0.15).delay(delay)
                        : KiddoTasksDesignTokens.KidsAnimations.gentle.delay(delay)
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func popIn(delay: Double = 0) -> some View {
        modifier(PopInModifier(delay: delay))
    }
}

// MARK: - Wiggle modifier

/// Wiggles a view left and right. Use to draw attention to interactive
/// elements (e.g. rewards the kid can afford).
struct WiggleModifier: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onChange(of: trigger) { _, newValue in
                guard !reduceMotion else { return }
                if newValue {
                    withAnimation(.easeInOut(duration: 0.12).repeatCount(3, autoreverses: true)) {
                        angle = 4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        angle = 0
                    }
                }
            }
    }
}

extension View {
    func wiggle(trigger: Bool) -> some View {
        modifier(WiggleModifier(trigger: trigger))
    }
}

// MARK: - Sparkle overlay

/// Tiny sparkle particles that orbit around a view. Use on affordable
/// rewards or selected avatars to make them feel magical.
struct SparkleOverlay: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        if !reduceMotion {
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Text("✨")
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                        .offset(
                            x: CGFloat(cos(Double(i) * 72 * .pi / 180 + (isAnimating ? .pi : 0))) * 32,
                            y: CGFloat(sin(Double(i) * 72 * .pi / 180 + (isAnimating ? .pi : 0))) * 32
                        )
                        .opacity(isAnimating ? 0.3 : 1)
                }
            }
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var color: Color = KiddoTasksDesignTokens.Colors.primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KiddoTasksDesignTokens.Typography.buttonLabel)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KiddoTasksDesignTokens.TouchTargets.recommended)
                .background {
                    let shape = RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.medium, style: .continuous)
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
    var color: Color = KiddoTasksDesignTokens.Colors.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KiddoTasksDesignTokens.Typography.buttonLabel)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: KiddoTasksDesignTokens.TouchTargets.recommended)
                .background(color.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.medium, style: .continuous)
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
    var photoData: Data? = nil

    var body: some View {
        Group {
            if let photoData, let uiImage = KiddoImageCache.image(from: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(avatar.emoji)
                    .font(.system(size: size * 0.52))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background {
            if photoData == nil {
                Circle().fill(Color(hex: avatar.colorHex).opacity(0.28))
            }
        }
        .overlay {
            Circle().strokeBorder(KiddoTasksDesignTokens.Colors.surfaceCard, lineWidth: max(1.5, size * 0.055))
        }
        .shadow(color: Color(hex: photoData == nil ? avatar.colorHex : "#888888").opacity(0.25), radius: size * 0.10, x: 0, y: size * 0.06)
    }
}

struct PointsBadge: View {
    let points: Int
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: compact ? 10 : 13, weight: .bold))
            Text("\(points)")
                .font(compact ? KiddoTasksDesignTokens.Typography.captionLarge : KiddoTasksDesignTokens.Typography.titleSmall)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(
                    reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7),
                    value: points
                )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(Capsule().fill(Color(hex: "#F59E0B")))
    }
}

// MARK: - Empty state

/// Single empty-state component for the whole app.
/// Owns the illustration (emoji + soft bob), title, message, and optional CTA.
struct EmptyStateView: View {
    var emoji: String = "✨"
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        emoji: String = "✨",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.emoji = emoji
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
            if !emoji.isEmpty {
                FloatingEmoji(emoji: emoji, size: 56, duration: reduceMotion ? 0 : 2.2)
                    .frame(width: 104, height: 104)
                    .background(Circle().fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                    .kiddotasksShadow(.medium)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.headingMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .padding(KiddoTasksDesignTokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Compact empty row for List sections (parent Tasks/Rewards).
struct EmptyListHint: View {
    let emoji: String
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 22))
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Cards

/// White rounded container used across the Parent Center.
struct SectionCard<Content: View>: View {
    let title: String
    var icon: String = "sparkles"
    var tint: Color = KiddoTasksDesignTokens.Colors.primary
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.small) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            }
            content
        }
        .padding(KiddoTasksDesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiddoTasksDesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous))
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
                .font(KiddoTasksDesignTokens.Typography.displaySmall)
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(KiddoTasksDesignTokens.Typography.taskLabel)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2, reservesSpace: true)
        }
        .padding(KiddoTasksDesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
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
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                StatusChip(status: completion?.status, fallback: task.category.displayName)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(task.pointValue)")
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .monospacedDigit()
            }
            .foregroundStyle(Color(hex: "#B45309"))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: "#FEF3C7")))
        }
        .padding(KiddoTasksDesignTokens.Spacing.medium)
        .background(KiddoTasksDesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.extraLarge, style: .continuous))
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
            .font(KiddoTasksDesignTokens.Typography.captionSmall)
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
        case .approved: return KiddoTasksDesignTokens.Colors.success
        case .awaitingApproval, .completed: return KiddoTasksDesignTokens.Colors.warning
        case .rejected: return KiddoTasksDesignTokens.Colors.error
        case .none: return KiddoTasksDesignTokens.Colors.textSecondary
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
                        .fill(KiddoTasksDesignTokens.Colors.accent)
                }
            Text(reward.name)
                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            Text(reward.description)
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(reward.pointCost)")
                        .monospacedDigit()
                }
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(Color(hex: "#B45309"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "#FEF3C7")))
                Spacer()
                if reward.canAfford(with: points) {
                    Text("Get")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(KiddoTasksDesignTokens.Colors.success))
                } else {
                    Text("Need \(reward.pointsNeeded(givenCurrentPoints: points))")
                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding(KiddoTasksDesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(KiddoTasksDesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.extraLarge, style: .continuous))
        .kiddotasksShadow(.medium)
    }
}

// MARK: - Haptic feedback

public enum Haptic {
    public static func light() { let gen = UIImpactFeedbackGenerator(style: .light); gen.impactOccurred() }
    public static func medium() { let gen = UIImpactFeedbackGenerator(style: .medium); gen.impactOccurred() }
    public static func success() { let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success) }
    public static func error() { let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.error) }
    public static func warning() { let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.warning) }
}

// MARK: - Skeleton loading

public struct SkeletonView: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false
    public init(height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(KiddoTasksDesignTokens.Colors.surfaceElevated)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(KiddoTasksDesignTokens.Colors.textTertiary.opacity(0.18))
                    .opacity(isPulsing ? 0.35 : 0.85)
            }
            .animation(
                reduceMotion
                    ? .default
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { if !reduceMotion { isPulsing = true } }
    }
}

/// A row of skeleton placeholders for loading list content.
public struct SkeletonListRow: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 12) {
            SkeletonView(height: 44, cornerRadius: 12).frame(width: 44)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 16)
                SkeletonView(height: 12).frame(width: 120)
            }
            Spacer()
        }
        .padding(12)
        .background(KiddoTasksDesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
