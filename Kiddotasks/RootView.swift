import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(ThemeStore.self) private var theme
    @State private var toastCenter = ToastCenter.shared

    var body: some View {
        // NOTE: Do not observe `store.dataRevision` here. Feature screens already
        // read the store properties they need via @Observable; forcing a full
        // root re-eval on every persist caused avoidable layout work.
        Group {
            switch appState.applicationMode {
            case .login:
                WelcomeView()
            case .parentControl:
                ParentControlCenter()
            case .kidsSelection:
                ChildSelectionView()
            case .kidsStation:
                KidsStationView()
            }
        }
        .animation(KiddoTasksDesignTokens.Animation.standard, value: modeID)
        .transaction { tx in
            // Subtle content crossfade; no large slide (feels calmer, less template-y).
            tx.animation = KiddoTasksDesignTokens.Animation.standard
        }
        .overlay(alignment: .bottom) {
            if let toast = toastCenter.current {
                ToastBannerView(item: toast) {
                    toastCenter.dismiss()
                }
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
    }

    private var modeID: String {
        switch appState.applicationMode {
        case .login: return "login"
        case .parentControl: return "parent"
        case .kidsSelection: return "kidsSelect"
        case .kidsStation: return "kids"
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(ThemeStore())
}
