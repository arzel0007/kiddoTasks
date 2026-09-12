import SwiftUI

/// Full-week celebration for a child (all 7 days had approved work).
struct WeekBonusCelebrationView: View {
    let childName: String
    let title: String
    let onDone: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎉")
                .font(.system(size: 72))
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.55),
                    value: appeared
                )
            Text(title.isEmpty ? "Full week!" : title)
                .font(KiddoTasksDesignTokens.Typography.displayMedium)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            Text("\(childName) showed up every day this week")
                .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Awesome!") { onDone() }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiddoTasksDesignTokens.Colors.rewardLight.ignoresSafeArea())
        .onAppear { appeared = true }
    }
}
