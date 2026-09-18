import SwiftUI

/// Shared avatar size so every surface matches (pt / logical).
enum ArzAvatarMetrics {
    /// Consistent display size across parent + kids headers.
    static let displaySize: CGFloat = 80
    /// How long the tap phrase stays visible.
    static let phraseVisibleDuration: TimeInterval = 2.5
    /// Gap under the header before page content starts.
    static let headerBottomGap: CGFloat = 12
}

/// Auto-dismissing speech/thinking bubble shown when Arz is tapped.
struct ArzPhraseBubble: View {
    let phrase: ArzPhrases.Line
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.title)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                Text(phrase.body)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(KiddoTasksDesignTokens.Colors.border)
        )
        .kiddotasksShadow(.medium)
        .allowsHitTesting(true)
        .onTapGesture(perform: onDismiss)
        .accessibilityLabel("\(phrase.title). \(phrase.body)")
        .accessibilityHint("Dismisses automatically")
    }
}

/// Flat inline page header matching Today: [Arz] Title (+ subtitle)  [actions]
/// Participates in normal layout flow — no floating card.
struct ArzPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    /// Optional personalized greeting (e.g. kid name in Kids Station).
    var greeting: (() -> ArzPhrases.Line)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var phrase: ArzPhrases.Line?
    @State private var dismissWork: DispatchWorkItem?

    var body: some View {
        // Fixed header height — the phrase bubble overlays content and never
        // reflows the page.
        HStack(alignment: .center, spacing: 12) {
            ArzHeadView(
                size: ArzAvatarMetrics.displaySize,
                interactive: false,
                onTapped: { sayHello() }
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.65),
                value: pressed
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.headingLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
        .padding(.vertical, 12)
        .frame(minHeight: 96, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Thinking-bubble overlay — does not change header/content layout.
        .overlay(alignment: .topLeading) {
            if let phrase {
                ArzPhraseBubble(phrase: phrase) {
                    hidePhrase()
                }
                .padding(.leading, KiddoTasksDesignTokens.Spacing.medium + 4)
                .padding(.top, ArzAvatarMetrics.displaySize - 12)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(5)
            }
        }
    }

    private func sayHello() {
        pressed = true
        // Do not swap the sprite on tap — only show the bubble.
        let next: ArzPhrases.Line = if let greeting { greeting() } else { ArzPhrases.next() }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.8)) {
            phrase = next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            pressed = false
        }
        dismissWork?.cancel()
        let work = DispatchWorkItem { hidePhrase() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ArzAvatarMetrics.phraseVisibleDuration,
            execute: work
        )
    }

    private func hidePhrase() {
        dismissWork?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            phrase = nil
        }
    }
}

extension ArzPageHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        greeting: (() -> ArzPhrases.Line)? = nil
    ) {
        self.init(title: title, subtitle: subtitle, greeting: greeting, trailing: { EmptyView() })
    }
}

#Preview {
    VStack(spacing: 0) {
        ArzPageHeader(title: "Tasks") {
            Image(systemName: "plus")
        }
        Spacer()
    }
}
