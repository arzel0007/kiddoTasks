import SwiftUI

enum ToastStyle: String, Identifiable, Equatable {
    case success
    case error
    case info

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return KiddoTasksDesignTokens.Colors.success
        case .error: return KiddoTasksDesignTokens.Colors.error
        case .info: return KiddoTasksDesignTokens.Colors.primary
        }
    }
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let style: ToastStyle
    let message: String
}

/// Lightweight in-app toast queue. Call `ToastCenter.shared.show(...)` from actions.
@Observable
@MainActor
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var current: ToastItem?
    private var dismissTask: Task<Void, Never>?

    func show(_ style: ToastStyle, _ message: String) {
        let item = ToastItem(style: style, message: message)
        withAnimation(KiddoTasksDesignTokens.Animation.standard) {
            current = item
        }
        switch style {
        case .success: Haptic.success()
        case .error: Haptic.error()
        case .info: Haptic.light()
        }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(KiddoTasksDesignTokens.Animation.standard) {
                    if self?.current?.id == item.id {
                        self?.current = nil
                    }
                }
            }
        }
    }

    func success(_ message: String) { show(.success, message) }
    func error(_ message: String) { show(.error, message) }
    func info(_ message: String) { show(.info, message) }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(KiddoTasksDesignTokens.Animation.standard) {
            current = nil
        }
    }
}

/// Bottom toast banner. Placed by `RootView` as a safe-area overlay.
struct ToastBannerView: View {
    let item: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: KiddoTasksDesignTokens.Spacing.small) {
            Image(systemName: item.style.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(item.style.tint)

            Text(item.message)
                .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
        .padding(.vertical, KiddoTasksDesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
                .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KiddoTasksDesignTokens.CornerRadius.large, style: .continuous)
                .strokeBorder(item.style.tint.opacity(0.25), lineWidth: 1)
        )
        .kiddotasksShadow(.large)
        .padding(.horizontal, KiddoTasksDesignTokens.Spacing.medium)
        .accessibilityElement(children: .combine)
    }
}
