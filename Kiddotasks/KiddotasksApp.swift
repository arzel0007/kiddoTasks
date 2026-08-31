import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct KiddotasksApp: App {
    @State private var appState = AppState()

    init() {
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseConfig.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
