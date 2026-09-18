import SwiftUI

// MARK: - Head

/// Animated Arz head.
/// Final avatar (web + iOS): muted looping `arz.mp4` when bundled.
/// Falls back to expression PNG stills on Reduce Motion or missing clip.
struct ArzHeadView: View {
    var size: CGFloat = 52
    var interactive: Bool = true
    /// Parent-owned tap handler (preferred for header integration).
    var onTapped: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = ArzCompanionController.shared
    @State private var blinkWorkItem: DispatchWorkItem?

    private var prefersVideo: Bool {
        !reduceMotion && ArzAvatarMedia.hasVideo
    }

    var body: some View {
        Group {
            if prefersVideo, let videoURL = ArzAvatarMedia.videoURL {
                ArzLoopVideoView(url: videoURL, size: size)
                    .clipShape(Circle())
            } else if reduceMotion {
                staticHead
            } else {
                animatedHead
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture {
            if let onTapped {
                onTapped()
            } else if interactive {
                Arz.handle(.userTap)
            }
        }
        .accessibilityLabel("Arz, KiddoTasks assistant")
        .accessibilityAddTraits(.isButton)
        // Never set allowsHitTesting(false) here — that blocks parent Buttons too.
        .onAppear { scheduleIdleBlink() }
        .onDisappear { blinkWorkItem?.cancel() }
    }

    private var headImageName: String {
        controller.isBlinking
            ? controller.expression.blinkAssetName
            : controller.expression.assetName
    }

    private var staticHead: some View {
        Image(headImageName)
            .resizable()
            .scaledToFit()
    }

    private var animatedHead: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let isIdleLike = controller.expression == .idle || controller.expression == .happy

            // Keep motion quiet so a header-sized Arz stays calm.
            let breathe = isIdleLike ? 1 + 0.01 * sin(t * .pi * 0.4) : 1.0
            let tilt = isIdleLike ? sin(t * .pi * 0.25) * 0.8 : 0.0
            let bob = isIdleLike ? sin(t * .pi * 0.3) * (size * 0.012) : 0.0

            let pop: CGFloat = {
                switch controller.expression {
                case .excited, .laughing: return 1.05
                case .surprised: return 1.03
                default: return 1.0
                }
            }()

            Image(headImageName)
                .resizable()
                .scaledToFit()
                .scaleEffect(breathe * pop)
                .rotationEffect(.degrees(tilt))
                .offset(y: bob)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: controller.playToken)
                .animation(.easeInOut(duration: 0.2), value: controller.expression)
        }
    }

    private func scheduleIdleBlink() {
        guard !reduceMotion else { return }
        blinkWorkItem?.cancel()
        let delay = Double.random(in: 2.8...5.5)
        let item = DispatchWorkItem {
            guard controller.expression == .idle || controller.expression == .happy else {
                scheduleIdleBlink()
                return
            }
            controller.setBlinking(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                controller.setBlinking(false)
                scheduleIdleBlink()
            }
        }
        blinkWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

#Preview {
    ArzHeadView(size: 52)
        .padding(24)
}
