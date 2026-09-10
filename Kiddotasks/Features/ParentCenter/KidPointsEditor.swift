import SwiftUI

/// Sheet for managing a child's points — add, deduct (bad deeds), set, or reset.
struct KidPointsEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var amount = 10
    @State private var reason = ""
    @State private var mode: Mode = .add
    @State private var setToValue = ""
    @State private var showResetConfirm = false

    enum Mode: String, CaseIterable, Identifiable {
        case add, deduct, set
        var id: String { rawValue }
        var label: String {
            switch self {
            case .add: return "Add"
            case .deduct: return "Deduct"
            case .set: return "Set"
            }
        }
        var fullLabel: String {
            switch self {
            case .add: return "Add points"
            case .deduct: return "Deduct (bad deed)"
            case .set: return "Set to value"
            }
        }
    }

    private var modeOptions: [KiddoChipOption<Mode>] {
        Mode.allCases.map { KiddoChipOption(id: $0, title: $0.label) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
                    KiddoFormSection(title: child.name, icon: "person.fill") {
                        HStack(spacing: 12) {
                            ChildAvatarView(avatar: child.avatar, size: 52, photoData: child.photoData)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(child.activePoints)")
                                    .font(KiddoTasksDesignTokens.Typography.displaySmall)
                                    .monospacedDigit()
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                Text("current balance")
                                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            }
                            Spacer()
                            PointsBadge(points: child.activePoints)
                        }
                    }

                    KiddoFormSection(title: "Action", icon: "slider.horizontal.3") {
                        KiddoChipPicker(label: "Mode", options: modeOptions, selection: $mode)
                            .padding(.bottom, 4)

                        switch mode {
                        case .set:
                            KiddoTextField(
                                label: "New balance",
                                placeholder: "e.g. 50",
                                text: $setToValue,
                                keyboard: .numberPad
                            )
                        case .add, .deduct:
                            KiddoPointsStepper(
                                label: mode == .deduct ? "Stars to remove" : "Stars to add",
                                value: $amount,
                                range: 1...500
                            )
                        }

                        KiddoTextField(
                            label: "Reason",
                            placeholder: mode == .deduct ? "Optional (shows in history)" : "Optional",
                            text: $reason
                        )

                        if mode == .deduct {
                            Text("Deductions appear in history and reduce the balance immediately.")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        }
                    }

                    KiddoFormSection(title: "Danger zone", icon: "exclamationmark.triangle") {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label("Reset points to zero", systemImage: "arrow.counterclockwise")
                                .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    PrimaryButton(title: "Apply", color: mode == .deduct ? KiddoTasksDesignTokens.Colors.warning : KiddoTasksDesignTokens.Colors.primary) {
                        apply()
                    }
                    .disabled(!canApply)
                    .opacity(canApply ? 1 : 0.5)
                }
                .padding(KiddoTasksDesignTokens.Spacing.medium)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Manage points")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .alert("Reset \(child.name)'s points?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    do {
                        try appState.store.resetPoints(for: child.id)
                        appState.toastSuccess("Points reset to zero")
                    } catch {
                        appState.toastError(error.localizedDescription)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will set their balance to zero. This cannot be undone.")
            }
        }
    }

    private var canApply: Bool {
        switch mode {
        case .add, .deduct:
            return amount > 0
        case .set:
            return Int(setToValue) != nil
        }
    }

    private func apply() {
        do {
            switch mode {
            case .add:
                try appState.store.adjustPoints(
                    for: child.id,
                    amount: amount,
                    reason: reason.isEmpty ? "Bonus points" : reason
                )
                appState.toastSuccess("Added \(amount) ★ to \(child.name)")
            case .deduct:
                try appState.store.adjustPoints(
                    for: child.id,
                    amount: -amount,
                    reason: reason.isEmpty ? "Deduction" : reason
                )
                appState.toastSuccess("Removed \(amount) ★ from \(child.name)")
            case .set:
                if let value = Int(setToValue) {
                    try appState.store.setPoints(for: child.id, to: value, reason: reason)
                    appState.toastSuccess("\(child.name) balance set to \(value)")
                }
            }
            dismiss()
        } catch {
            appState.toastError(error.localizedDescription)
            appState.presentError(error)
        }
    }
}
