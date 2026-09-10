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
        // No root `.animation`/`.transaction` — those overrode NavigationStack
        // push/pop and tab transitions (janky navigation).
        .overlay(alignment: .top) {
            if appState.cloudSyncStatus == .pending
                || appState.cloudSyncStatus == .syncing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(appState.cloudSyncStatus == .syncing ? "Syncing…" : "Waiting to sync…")
                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.95)))
                .padding(.top, 4)
                .zIndex(9)
            } else if case .error = appState.cloudSyncStatus {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                    Text("Offline — changes save on this device")
                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.95)))
                .padding(.top, 4)
                .zIndex(9)
            }
        }
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
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(ThemeStore())
}
