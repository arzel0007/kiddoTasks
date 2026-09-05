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
            case .add: return "Add points"
            case .deduct: return "Deduct (bad deed)"
            case .set: return "Set to value"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ChildAvatarView(avatar: child.avatar, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name)
                                .font(KiddotasksDesignTokens.Typography.titleMedium)
                            Text("\(child.activePoints) ⭐ balance")
                                .font(KiddotasksDesignTokens.Typography.captionLarge)
                                .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                        }
                    }
                }

                Section("Action") {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .set {
                        TextField("New balance", text: $setToValue)
                            .keyboardType(.numberPad)
                    } else {
                        Stepper("\(mode == .deduct ? "-" : "+")\(amount) ⭐", value: $amount, in: 1...500)
                    }

                    TextField("Reason (optional)", text: $reason)
                }

                if mode == .deduct {
                    Section {
                        Text("Deductions appear in the child's history and reduce their balance immediately.")
                            .font(KiddotasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddotasksDesignTokens.Colors.textSecondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset points to zero", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Manage points")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: apply)
                        .disabled(!canApply)
                }
            }
            .alert("Reset \(child.name)'s points?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    try? appState.store.resetPoints(for: child.id)
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
                try appState.store.adjustPoints(for: child.id, amount: amount, reason: reason.isEmpty ? "Bonus points" : reason)
            case .deduct:
                try appState.store.adjustPoints(for: child.id, amount: -amount, reason: reason.isEmpty ? "Deduction" : reason)
            case .set:
                if let value = Int(setToValue) {
                    try appState.store.setPoints(for: child.id, to: value, reason: reason)
                }
            }
            dismiss()
        } catch {
            appState.presentError(error)
        }
    }
}