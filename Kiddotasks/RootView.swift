import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let _ = appState.store.dataRevision
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
        .animation(KiddotasksDesignTokens.Animation.standard, value: modeID)
        .alert("Something went wrong", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.clearError() } }
        )) {
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
}
