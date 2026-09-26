import SwiftUI

// MARK: - Bottom sheet chrome

/// Consistent bottom-sheet presentation: detents, drag grabber, and surface.
/// Apply to any `.sheet` content so forms, approvals, and details share one feel.
struct KiddoBottomSheetChrome: ViewModifier {
    var detents: Set<PresentationDetent> = [.medium, .large]
    var showGrabber: Bool = true

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(showGrabber ? .visible : .hidden)
            .presentationBackground {
                KiddoTasksDesignTokens.Colors.surface
                    .ignoresSafeArea()
            }
            .presentationCornerRadius(KiddoTasksDesignTokens.CornerRadius.extraLarge)
            .interactiveDismissDisabled(false)
    }
}

extension View {
    /// Style sheet content as a Calm Adventure bottom sheet.
    func kiddoBottomSheet(
        detents: Set<PresentationDetent> = [.medium, .large],
        grabber: Bool = true
    ) -> some View {
        modifier(KiddoBottomSheetChrome(detents: detents, showGrabber: grabber))
    }

    /// Compact form sheet (single field, quick action).
    func kiddoBottomSheetCompact() -> some View {
        kiddoBottomSheet(detents: [.height(280), .medium, .large])
    }

    /// Tall form sheet (create/edit editors).
    func kiddoBottomSheetForm() -> some View {
        kiddoBottomSheet(detents: [.large])
    }
}

// MARK: - Bottom sheet container (title + optional subtitle + content)

/// Standard header used inside bottom sheets and action sheets.
struct KiddoSheetHeader: View {
    let title: String
    var subtitle: String?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KiddoTasksDesignTokens.Typography.headingMedium)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(KiddoPressStyle())
                    .accessibilityLabel("Close")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KiddoTasksDesignTokens.Spacing.large)
        .padding(.top, KiddoTasksDesignTokens.Spacing.medium)
        .padding(.bottom, KiddoTasksDesignTokens.Spacing.small)
    }
}

// MARK: - Action sheet (slide-up, tap outside to dismiss)

/// Branded action sheet: slides from the bottom, swipe/tap outside to dismiss.
/// Use for destructive confirms and “choose an action” menus.
struct KiddoActionSheet: View {
    struct Action {
        enum Role {
            case `default`
            case destructive
            case cancel
        }

        let title: String
        var role: Role = .default
        var isDisabled: Bool = false
        let handler: () -> Void

        static func `default`(_ title: String, handler: @escaping () -> Void) -> Action {
            Action(title: title, role: .default, handler: handler)
        }

        static func destructive(_ title: String, handler: @escaping () -> Void) -> Action {
            Action(title: title, role: .destructive, handler: handler)
        }

        static func cancel(_ title: String = "Cancel", handler: @escaping () -> Void = {}) -> Action {
            Action(title: title, role: .cancel, handler: handler)
        }
    }

    let title: String
    var message: String?
    let actions: [Action]
    let onDismiss: () -> Void

    @State private var appeared = false

    private var nonCancelActions: [Action] { actions.filter { $0.role != .cancel } }
    private var cancelActions: [Action] { actions.filter { $0.role == .cancel } }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: KiddoTasksDesignTokens.Spacing.small) {
                grabber

                VStack(spacing: KiddoTasksDesignTokens.Spacing.xSmall) {
                    Text(title)
                        .font(KiddoTasksDesignTokens.Typography.titleMedium)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let message {
                        Text(message)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
                .padding(.top, KiddoTasksDesignTokens.Spacing.xSmall)
                .padding(.bottom, KiddoTasksDesignTokens.Spacing.small)

                VStack(spacing: KiddoTasksDesignTokens.Spacing.xSmall) {
                    ForEach(Array(nonCancelActions.enumerated()), id: \.offset) { _, action in
                        actionButton(action, prominent: true)
                    }
                }
                .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)

                if !cancelActions.isEmpty {
                    VStack(spacing: KiddoTasksDesignTokens.Spacing.xSmall) {
                        ForEach(Array(cancelActions.enumerated()), id: \.offset) { _, action in
                            actionButton(action, prominent: false)
                        }
                    }
                    .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
                    .padding(.top, KiddoTasksDesignTokens.Spacing.xxSmall)
                }
            }
            .padding(.bottom, KiddoTasksDesignTokens.Spacing.large)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: KiddoTasksDesignTokens.CornerRadius.extraLarge,
                    topTrailingRadius: KiddoTasksDesignTokens.CornerRadius.extraLarge,
                    style: .continuous
                )
                .fill(KiddoTasksDesignTokens.Colors.surface)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
            )
            .offset(y: appeared ? 0 : 420)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 60 { dismiss() }
                    }
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                appeared = true
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(KiddoTasksDesignTokens.Colors.border)
            .frame(width: 40, height: 5)
            .padding(.top, KiddoTasksDesignTokens.Spacing.small)
    }

    private func actionButton(_ action: Action, prominent: Bool) -> some View {
        Button {
            dismiss()
            // Let the sheet dismiss animation start before the handler mutates state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action.handler()
            }
        } label: {
            Text(action.title)
                .font(KiddoTasksDesignTokens.Typography.buttonLabel)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(labelColor(for: action, prominent: prominent))
                .background(
                    RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.medium, style: .continuous)
                        .fill(fillColor(for: action, prominent: prominent))
                )
        }
        .buttonStyle(KiddoPressStyle())
        .disabled(action.isDisabled)
        .opacity(action.isDisabled ? 0.5 : 1)
    }

    private func labelColor(for action: Action, prominent: Bool) -> Color {
        switch action.role {
        case .destructive:
            return prominent ? .white : KiddoTasksDesignTokens.Colors.error
        case .cancel:
            return KiddoTasksDesignTokens.Colors.primary
        case .default:
            return prominent ? .white : KiddoTasksDesignTokens.Colors.primary
        }
    }

    private func fillColor(for action: Action, prominent: Bool) -> Color {
        switch action.role {
        case .destructive:
            return prominent ? KiddoTasksDesignTokens.Colors.error : KiddoTasksDesignTokens.Colors.attentionLight
        case .cancel:
            return KiddoTasksDesignTokens.Colors.surfaceCard
        case .default:
            return prominent ? KiddoTasksDesignTokens.Colors.primary : KiddoTasksDesignTokens.Colors.primaryLight
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}

/// Presents `KiddoActionSheet` as an overlay when `item` is non-nil.
/// Overlay avoids fighting with `.sheet` presentations already on the screen.
struct KiddoActionSheetPresenter<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let title: String
    var message: String?
    let actions: (Item) -> [KiddoActionSheet.Action]

    func body(content: Content) -> some View {
        content.overlay {
            if let value = item {
                KiddoActionSheet(
                    title: title,
                    message: message,
                    actions: actions(value),
                    onDismiss: { item = nil }
                )
                .transition(.opacity)
            }
        }
    }
}

extension View {
    /// Slide-up action sheet for destructive / choose-an-action menus.
    func kiddoActionSheet<Item: Identifiable>(
        item: Binding<Item?>,
        title: String,
        message: String? = nil,
        actions: @escaping (Item) -> [KiddoActionSheet.Action]
    ) -> some View {
        modifier(
            KiddoActionSheetPresenter(
                item: item,
                title: title,
                message: message,
                actions: actions
            )
        )
    }
}

// MARK: - Bottom-sheet form shell

/// Scrollable form body used by bottom-sheet editors (tasks, rewards, wishlist…).
struct KiddoSheetFormChrome<Content: View>: View {
    var title: String
    var subtitle: String?
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            KiddoSheetHeader(title: title, subtitle: subtitle, onDismiss: onDismiss)
            ScrollView {
                content
                    .padding(.horizontal, KiddoTasksDesignTokens.Spacing.large)
                    .padding(.bottom, KiddoTasksDesignTokens.Spacing.xLarge)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KiddoTasksDesignTokens.Colors.surface)
    }
}
