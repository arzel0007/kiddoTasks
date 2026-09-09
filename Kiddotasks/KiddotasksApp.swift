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
    @State private var showSplash = true

    init() {
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseConfig.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                } else {
                    RootView()
                        .environment(appState)
                }
            }
        }
    }
}
