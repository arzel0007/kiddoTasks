import SwiftUI

/// Splash shown on launch.
///
/// Prefers the bundled rocket intro video when Reduce Motion is off.
/// Video clip is ~8s — we hold ~3s so the intro is enjoyable, then fade.
/// RootView is already mounted underneath — no blank gap after dismiss.
struct SplashView: View {
    var isReady: Bool
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appearedAt = Date()
    @State private var logoVisible = false
    @State private var wordmarkVisible = false
    @State private var taglineVisible = false
    @State private var didFinish = false

    /// Short logo-only beat (no video / Reduce Motion).
    private let logoMinDisplay: TimeInterval = 1.0
    /// Long enough to enjoy the rocket intro (~8s clip), not the full length.
    private let videoMinDisplay: TimeInterval = 3.0
    /// Absolute ceiling — never block launch past this.
    private let hardCap: TimeInterval = 3.5
    private let videoResourceName = "Boy_riding_rocket_in_space"

    private var hasVideoAsset: Bool {
        Bundle.main.url(forResource: videoResourceName, withExtension: "mp4") != nil
    }

    private var useVideo: Bool { hasVideoAsset && !reduceMotion }

    private var minDisplay: TimeInterval {
        useVideo ? videoMinDisplay : logoMinDisplay
    }

    var body: some View {
        GeometryReader { geo in
            // Scale lockup from the shorter axis so landscape/tablets stay balanced.
            let unit = min(geo.size.width, geo.size.height)
            let logoSize = max(72, min(128, unit * 0.22))

            ZStack {
                if useVideo {
                    Color.black.ignoresSafeArea()
                    SplashVideoLayer(
                        resourceName: videoResourceName,
                        fileExtension: "mp4",
                        isMuted: true
                    )
                    .ignoresSafeArea()

                    VStack {
                        Spacer()
                        brandLockup(logoSize: logoSize)
                            .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 16))
                    }
                    .opacity(logoVisible ? 1 : 0)
                } else {
                    KiddoTasksDesignTokens.PageBackgrounds.welcome.ignoresSafeArea()
                    VStack(spacing: KiddoTasksDesignTokens.Spacing.large) {
                        Spacer()
                        KiddoTasksLogoMark(size: logoSize)
                            .scaleEffect(logoVisible ? 1 : 0.86)
                            .opacity(logoVisible ? 1 : 0)
                        Text("KiddoTasks")
                            .font(KiddoTasksDesignTokens.Typography.displayMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                            .minimumScaleFactor(0.7)
                            .opacity(wordmarkVisible ? 1 : 0)
                        Text("Missions for kids. Support for parents.")
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .opacity(taglineVisible ? 1 : 0)
                        Spacer()
                    }
                    .padding(KiddoTasksDesignTokens.Spacing.xLarge)
                }
            }
        }
        .onAppear {
            appearedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.08)) {
                logoVisible = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.18)) {
                wordmarkVisible = true
                taglineVisible = true
            }
            Task { await scheduleExit() }
        }
    }

    private func brandLockup(logoSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            KiddoTasksLogoMark(size: logoSize * 0.55)
            Text("KiddoTasks")
                .font(KiddoTasksDesignTokens.Typography.headingLarge)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
            Text("Missions for kids. Support for parents.")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        }
        .multilineTextAlignment(.center)
        .opacity(logoVisible ? 1 : 0)
    }

    @MainActor
    private func scheduleExit() async {
        // Hold for the brand/intro beat, then exit once ready.
        // Never wait for the entire 8s clip.
        while !didFinish {
            let elapsed = Date().timeIntervalSince(appearedAt)
            if elapsed >= hardCap {
                finish()
                return
            }
            if isReady, elapsed >= minDisplay {
                finish()
                return
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    @MainActor
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}
