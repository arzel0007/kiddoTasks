import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeStore.self) private var theme
    @State private var toastCenter = ToastCenter.shared

    var body: some View {
        // Re-eval when navigation-relevant state changes (Observation + computed mode).
        let _ = appState.gamesTabRequested
        let _ = appState.currentChildProfile?.id
        let _ = appState.interfaceOverride
        let _ = appState.kidsSessionUnlocked
        let mode = appState.applicationMode

        Group {
            switch mode {
            case .login:
                WelcomeView()
            case .parentControl:
                ParentControlCenter()
            case .kidsSelection:
                ChildSelectionView()
            case .kidsStation:
                KidsStationView()
                // Identity so TabView resets cleanly when switching profiles.
                    .id("kids-\(appState.currentChildProfile?.id ?? "games")")
            }
        }
        // No root `.animation`/`.transaction` — those overrode NavigationStack
        // push/pop and tab transitions (janky navigation).
        // Arz lives in each page header (ArzPageHeader / arzNavigationTitle) —
        // not as a shell overlay.
        .overlay(alignment: .bottom) {
            if let toast = toastCenter.current {
                ToastBannerView(
                    item: toast,
                    onDismiss: { toastCenter.dismiss() },
                    onAction: { toastCenter.performAction() }
                )
                .padding(.bottom, 72)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { appState.clearError() }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onChange(of: mode) { _, newMode in
            switch newMode {
            case .login:
                Arz.returnToIdle()
            case .kidsStation:
                Arz.handle(.kidsStationOpened)
            case .kidsSelection, .parentControl:
                Arz.handle(.dashboardOpened)
            }
        }
        .onChange(of: appState.errorMessage) { _, message in
            if message != nil {
                Arz.handle(.error)
            }
        }
        .onChange(of: appState.store.achievements.count) { _, count in
            // Achievement unlocks bump this array; react without touching store logic.
            if count > 0 {
                Arz.handle(.achievementUnlocked)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(ThemeStore())
}
