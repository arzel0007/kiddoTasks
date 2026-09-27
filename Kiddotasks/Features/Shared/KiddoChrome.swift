import SwiftUI
import UIKit

// MARK: - Floating pill tab bar

/// One item in the floating bottom bar.
struct KiddoTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
    }
}

/// Floating solid-white pill tab bar (inset from edges, rounded, elevated).
/// Matches the product target: content scrolls under the bar; selection is a
/// soft highlight behind the icon + blue label.
struct KiddoFloatingTabBar: View {
    @Binding var selection: Int
    let items: [KiddoTabItem]
    var tint: Color = KiddoTasksDesignTokens.Colors.primary
    var labelStyle: KiddoTabLabelStyle = .iconsOnly

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var barHeight: CGFloat {
        labelStyle == .iconsOnly ? 56 : 72
    }
    private let selectionFill = Color(hex: "#E8EDF2")

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    guard selection != index else { return }
                    Haptic.light()
                    withAnimation(
                        reduceMotion
                            ? .easeInOut(duration: 0.12)
                            : .spring(response: 0.28, dampingFraction: 0.78)
                    ) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectionFill)
                                    .frame(width: 52, height: 32)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Image(systemName: item.systemImage)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    selection == index
                                        ? tint
                                        : KiddoTasksDesignTokens.Colors.text
                                )
                        }
                        .frame(height: 32)

                        if labelStyle == .iconsAndText {
                            Text(item.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    selection == index
                                        ? tint
                                        : KiddoTasksDesignTokens.Colors.text
                                )
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(selection == index ? [.isSelected, .isButton] : .isButton)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, labelStyle == .iconsOnly ? 8 : 10)
        .frame(height: barHeight)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color(hex: "#E6EBF0"), lineWidth: 1)
        )
    }
}

extension View {
    /// Overlay the floating pill tab bar. Content should include bottom padding
    /// so list rows can scroll clear of the bar.
    func kiddoFloatingTabBar(
        selection: Binding<Int>,
        items: [KiddoTabItem],
        tint: Color = KiddoTasksDesignTokens.Colors.primary,
        labelStyle: KiddoTabLabelStyle = .iconsOnly
    ) -> some View {
        ZStack {
            self
            VStack {
                Spacer(minLength: 0)
                KiddoFloatingTabBar(selection: selection, items: items, tint: tint, labelStyle: labelStyle)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

// MARK: - Floating add (FAB)

/// One-hand-friendly primary add action — bottom trailing, just above the tab bar.
struct KiddoFloatingAddButton: View {
    var title: String = "Add"
    var tint: Color = KiddoTasksDesignTokens.Colors.primary
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: {
            Haptic.light()
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(tint)
                        .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
                )
                .scaleEffect(pressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in
                    if reduceMotion {
                        pressed = false
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            pressed = false
                        }
                    }
                }
        )
    }
}

extension View {
    /// Overlay a floating add button just above the floating pill tab bar.
    func kiddoFloatingAdd(
        title: String = "Add",
        tint: Color = KiddoTasksDesignTokens.Colors.primary,
        action: @escaping () -> Void
    ) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                KiddoFloatingAddButton(title: title, tint: tint, action: action)
                    // Clears the floating pill bar (~82pt + inset).
                    .padding(.trailing, 18)
                    .padding(.bottom, 96)
            }
    }
}
