import SwiftUI

/// Kids Station entry without a parent password.
/// Unlocks from local PIN, or cloud `openKidsSession` when Firebase is on.
struct KidsPINUnlockView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var isBusy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.large) {
                    KiddoTasksLogoMark(size: 72)
                        .padding(.top, 12)
                    VStack(spacing: 6) {
                        Text("Kids Station")
                            .font(KiddoTasksDesignTokens.Typography.displaySmall)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        Text("Enter your family PIN to play")
                            .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }

                    KiddoTextField(
                        label: "Family PIN",
                        placeholder: "4–6 digits",
                        text: $pin,
                        keyboard: .numberPad,
                        isSecure: true
                    )
                    .onChange(of: pin) { _, newValue in
                        pin = String(newValue.prefix(6).filter(\.isNumber))
                    }

                    if let errorText {
                        Text(errorText)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                    }

                    PrimaryButton(title: isBusy ? "Checking…" : "Unlock") {
                        unlock()
                    }
                    .disabled(pin.count < 4 || isBusy)
                    .opacity(isBusy ? 0.7 : 1)

                    Text("Ask a parent for the PIN in Family → Kids PIN.")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(KiddoTasksDesignTokens.Spacing.xLarge)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
            .navigationTitle("Kids")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func unlock() {
        errorText = nil
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            let ok = await appState.unlockKidsStation(pin: pin)
            if ok {
                dismiss()
            } else {
                errorText = "That PIN didn’t work. Try again."
            }
        }
    }
}
