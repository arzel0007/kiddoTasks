import SwiftUI

/// Splash screen shown on app launch. Displays the logo, app name, and an
/// animated progress bar. Dismisses after a minimum display time plus data load.
struct SplashView: View {
    var onFinish: () -> Void

    @State private var progress: Double = 0
    @State private var animationStarted = false

    private let minimumDisplayTime: TimeInterval = 3

    var body: some View {
        ZStack {
            KiddoTasksDesignTokens.PageBackgrounds.welcome.ignoresSafeArea()

            VStack(spacing: KiddoTasksDesignTokens.Spacing.xLarge) {
                Spacer()

                KiddoTasksLogoMark(size: 120)

                Text("KiddoTasks")
                    .font(KiddoTasksDesignTokens.Typography.displayMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)

                Text("Missions for kids. Control for parents.")
                    .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Animated progress bar
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(KiddoTasksDesignTokens.Colors.primary)
                    .frame(width: 200)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    .onAppear {
                        startProgress()
                    }
                    .padding(.bottom, KiddoTasksDesignTokens.Spacing.xxLarge)
            }
            .padding()
        }
        .onAppear {
            startMinimumTimer()
        }
    }

    private func startProgress() {
        progress = 0
        withAnimation(.easeInOut(duration: minimumDisplayTime)) {
            progress = 1.0
        }
    }

    private func startMinimumTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
            onFinish()
        }
    }
}