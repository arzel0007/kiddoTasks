import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(UIKit)
import UIKit
#endif

@main
struct KiddoTasksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var theme = ThemeStore()
    @State private var showSplash = true
    @State private var launchReady = false

    /// Process start for a rough time-to-interactive log (Phase 7 measurement).
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
                if showSplash {
                    SplashView(isReady: launchReady) {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            showSplash = false
                        }
                        let ms = Int(Date().timeIntervalSince(Self.processStart) * 1000)
                        print("[Perf] Splash dismissed after \(ms)ms from process start")
                    }
                    .transition(.opacity)
                } else {
                    RootView()
                        .environment(appState)
                        .environment(theme)
                        .preferredColorScheme(theme.appearance.preferredColorScheme)
                        .transition(.opacity)
                }
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    launchReady = true
                }
            }
        }
    }
}
