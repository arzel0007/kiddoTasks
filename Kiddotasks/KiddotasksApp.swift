import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(UIKit)
import UIKit
#endif

@main
struct KiddotasksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var theme = ThemeStore()
    @State private var showSplash = true
    @State private var launchReady = false

    /// Process start for a rough time-to-interactive log.
    private static let processStart = Date()

    init() {
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseConfig.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Mount the real app immediately so the first heavy frame is
                // painted *under* the splash — no blank gap after dismiss.
                RootView()
                    .environment(appState)
                    .environment(theme)
                    .preferredColorScheme(theme.appearance.preferredColorScheme)
                    // Keep hit-testing off while splash is up.
                    .allowsHitTesting(!showSplash)
                    .opacity(showSplash ? 0.01 : 1)

                if showSplash {
                    SplashView(isReady: launchReady) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showSplash = false
                        }
                        let ms = Int(Date().timeIntervalSince(Self.processStart) * 1000)
                        print("[Perf] Splash dismissed after \(ms)ms from process start")
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                // Mark ready on the next runloop turn — don't sleep.
                Task { @MainActor in
                    launchReady = true
                    if let route = AppState.sharedNotificationRoute {
                        AppState.sharedNotificationRoute = nil
                        appState.handleNotificationRoute(route)
                    }
                }
            }
            .onChange(of: AppState.sharedNotificationRoute) { _, route in
                guard let route else { return }
                AppState.sharedNotificationRoute = nil
                appState.handleNotificationRoute(route)
            }
        }
    }
}
