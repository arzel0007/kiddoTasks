import SwiftUI

// MARK: - Field chrome

/// Labeled input with consistent focus, padding, and surface — not raw Form rows.
struct KiddoFieldContainer<Content: View>: View {
    let label: String
    var caption: String?
    var isFocused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.semibold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            content
                .padding(.horizontal, KiddoTasksDesignTokens.Spacing.small)
                .padding(.vertical, KiddoTasksDesignTokens.Spacing.small)
                .background(
                    RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.medium, style: .continuous)
                        .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.medium, style: .continuous)
                        .strokeBorder(
                            isFocused
                                ? KiddoTasksDesignTokens.Colors.primary.opacity(0.55)
                                : KiddoTasksDesignTokens.Colors.borderSubtle,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
            if let caption {
                Text(caption)
                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
            }
        }
    }
}

/// Single-line text field in Kiddo chrome.
struct KiddoTextField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var caption: String?
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false

    @State private var isFocused = false
    @State private var revealSecure = false

    var body: some View {
        KiddoFieldContainer(label: label, caption: caption, isFocused: isFocused) {
            HStack(spacing: 8) {
                if isSecure && !revealSecure {
                    SecureField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .onSubmit { isFocused = false }
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                        .onSubmit { isFocused = false }
                }
                if isSecure {
                    Button {
                        revealSecure.toggle()
                    } label: {
                        Image(systemName: revealSecure ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealSecure ? "Hide password" : "Show password")
                }
            }
        }
        .onChange(of: text) { _, _ in isFocused = !text.isEmpty }
    }
}

/// Multi-line description field.
struct KiddoTextArea: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String

    var body: some View {
        KiddoFieldContainer(label: label) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Points stepper + free-form input

struct KiddoPointsStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...100
    var step: Int = 1
    var unit: String = "★"

    @State private var draft: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        KiddoFieldContainer(label: label) {
            HStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
                stepButton(system: "minus") {
                    commitDraft()
                    value = max(range.lowerBound, value - step)
                    draft = "\(value)"
                    Haptic.light()
                }
                .disabled(value <= range.lowerBound)

                Spacer(minLength: 4)

                TextField("0", text: $draft)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(KiddoTasksDesignTokens.Typography.displaySmall)
                    .monospacedDigit()
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    .focused($isFieldFocused)
                    .frame(minWidth: 64)
                    .onChange(of: draft) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(4))
                        if digits != newValue { draft = digits }
                    }
                    .onSubmit(applyTypedValue)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { applyTypedValue() }
                        }
                    }

                Text(unit)
                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.warning)

                Spacer(minLength: 4)

                stepButton(system: "plus") {
                    commitDraft()
                    value = min(range.upperBound, value + step)
                    draft = "\(value)"
                    Haptic.light()
                }
                .disabled(value >= range.upperBound)
            }
            .padding(.vertical, 2)
        }
        .onAppear { draft = "\(value)" }
    }

    private func commitDraft() {
        if let typed = Int(draft) {
            value = min(max(typed, range.lowerBound), range.upperBound)
        }
    }

    private func applyTypedValue() {
        commitDraft()
        draft = "\(value)"
        isFieldFocused = false
        Haptic.light()
    }

    private func stepButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(KiddoTasksDesignTokens.Colors.primarySoft)
                )
        }
        .buttonStyle(KiddoPressStyle())
    }
}

// MARK: - Chip picker

struct KiddoChipOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
}

/// Horizontal wrap of selectable chips — replaces menu pickers for short lists.
struct KiddoChipPicker<ID: Hashable>: View {
    let label: String
    let options: [KiddoChipOption<ID>]
    @Binding var selection: ID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.semibold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        withAnimation(KiddoTasksDesignTokens.Animation.quick) {
                            selection = option.id
                        }
                        Haptic.light()
                    } label: {
                        Text(option.title)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                selection == option.id
                                    ? .white
                                    : KiddoTasksDesignTokens.Colors.text
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    selection == option.id
                                        ? KiddoTasksDesignTokens.Colors.primary
                                        : KiddoTasksDesignTokens.Colors.surfaceCard
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    selection == option.id
                                        ? Color.clear
                                        : KiddoTasksDesignTokens.Colors.borderSubtle,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(KiddoPressStyle())
                }
            }
        }
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxWidth == .infinity ? maxX : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Section shell for custom editors

struct KiddoFormSection<Content: View>: View {
    let title: String
    var icon: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KiddoTasksDesignTokens.Spacing.small) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                }
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            }
            content
        }
        .padding(KiddoTasksDesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
                .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
                .strokeBorder(KiddoTasksDesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
