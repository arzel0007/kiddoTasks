import SwiftUI

/// Splash shown on launch.
///
/// Prefers the bundled rocket intro video (`Images/Boy_riding_rocket_in_space.mp4`).
/// Falls back to the logo beat if the asset is missing or Reduce Motion is on.
/// Exits when the clip ends (or after a short ready wait) / hard cap.
struct SplashView: View {
    var isReady: Bool
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appearedAt = Date()
    @State private var logoVisible = false
    @State private var wordmarkVisible = false
    @State private var taglineVisible = false
    @State private var didFinish = false
    @State private var videoFinished = false

    private let hardCap: TimeInterval = 6.0
    private let minDisplay: TimeInterval = 1.1
    private let videoResourceName = "Boy_riding_rocket_in_space"

    private var hasVideoAsset: Bool {
        Bundle.main.url(forResource: videoResourceName, withExtension: "mp4") != nil
    }

    private var useVideo: Bool { hasVideoAsset && !reduceMotion }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if useVideo {
                SplashVideoLayer(
                    resourceName: videoResourceName,
                    fileExtension: "mp4",
                    isMuted: true
                ) {
                    videoFinished = true
                    Task { await maybeFinish(force: false) }
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    brandLockup
                        .padding(.bottom, 36)
                }
                .opacity(logoVisible ? 1 : 0)
            } else {
                KiddoTasksDesignTokens.PageBackgrounds.welcome.ignoresSafeArea()
                VStack(spacing: KiddoTasksDesignTokens.Spacing.large) {
                    Spacer()
                    KiddoTasksLogoMark(size: 112)
                        .scaleEffect(logoVisible ? 1 : 0.86)
                        .opacity(logoVisible ? 1 : 0)
                    Text("KiddoTasks")
                        .font(KiddoTasksDesignTokens.Typography.displayMedium)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                        .opacity(wordmarkVisible ? 1 : 0)
                    Text("Missions for kids. Control for parents.")
                        .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(taglineVisible ? 1 : 0)
                    Spacer()
                }
                .padding(KiddoTasksDesignTokens.Spacing.xLarge)
            }
        }
        .onAppear {
            appearedAt = Date()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78).delay(0.15)) {
                logoVisible = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.28)) {
                wordmarkVisible = true
                taglineVisible = true
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(minDisplay * 1_000_000_000))
                await maybeFinish(force: false)
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(hardCap * 1_000_000_000))
                await maybeFinish(force: true)
            }
        }
    }

    private var brandLockup: some View {
        VStack(spacing: 6) {
            Text("KiddoTasks")
                .font(KiddoTasksDesignTokens.Typography.headingLarge)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
            Text("Missions for kids. Control for parents.")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .multilineTextAlignment(.center)
    }

    @MainActor
    private func maybeFinish(force: Bool) async {
        guard !didFinish else { return }

        let elapsed = Date().timeIntervalSince(appearedAt)
        if elapsed < minDisplay {
            try? await Task.sleep(nanoseconds: UInt64((minDisplay - elapsed) * 1_000_000_000))
        }
        guard !didFinish else { return }

        if !force {
            if useVideo {
                // Let the clip play; if the app is already ready and the clip is
                // still going, allow a soft exit after a bit so we never block.
                let deadline = appearedAt.addingTimeInterval(hardCap - 0.4)
                while !videoFinished, Date() < deadline {
                    if isReady, Date().timeIntervalSince(appearedAt) > minDisplay + 1.0 {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            } else {
                let deadline = Date().addingTimeInterval(1.0)
                while !isReady, Date() < deadline {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }

        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}
