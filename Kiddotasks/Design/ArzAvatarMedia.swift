import AVFoundation
import SwiftUI

/// Final avatar media: looping `arz.mp4` (matches web `/arz/arz.mp4`).
/// Bundled under `Kiddotasks/Images/` via the synchronized Xcode group.
enum ArzAvatarMedia {
    static let videoResourceName = "arz"
    static let videoFileExtension = "mp4"
    /// Still used when Reduce Motion is on or the clip is missing from the bundle.
    static let fallbackHeadAsset = "kiddo_head_happy"

    static var videoURL: URL? {
        if let url = Bundle.main.url(forResource: videoResourceName, withExtension: videoFileExtension) {
            return url
        }
        // Older emotion-cycle clip, if `arz.mp4` is not in the target yet.
        return Bundle.main.url(
            forResource: "Boy_animated_avatar_cycling_emotions",
            withExtension: videoFileExtension
        )
    }

    static var hasVideo: Bool { videoURL != nil }
}

/// Muted looping AVPlayer cropped to a circle for header avatars.
struct ArzLoopVideoView: UIViewRepresentable {
    let url: URL
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerCirclesView {
        let view = PlayerCirclesView()
        view.backgroundColor = .white
        view.layer.cornerRadius = size / 2
        view.layer.masksToBounds = true
        // 1280×720 source cropped to a circle (face sits upper-center).
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.start(url: url, layer: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerCirclesView, context: Context) {
        context.coordinator.ensurePlaying()
    }

    static func dismantleUIView(_ uiView: PlayerCirclesView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class PlayerCirclesView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    @MainActor
    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var endObserver: NSObjectProtocol?

        func start(url: URL, layer: AVPlayerLayer) {
            teardown()
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer(playerItem: item)
            queue.isMuted = true
            queue.actionAtItemEnd = .advance
            // AVPlayerLooper restarts the template item seamlessly.
            looper = AVPlayerLooper(player: queue, templateItem: item)
            layer.player = queue
            player = queue
            queue.play()
        }

        func ensurePlaying() {
            if player?.timeControlStatus != .playing {
                player?.play()
            }
        }

        func teardown() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            player?.pause()
            looper = nil
            player = nil
        }
    }
}
