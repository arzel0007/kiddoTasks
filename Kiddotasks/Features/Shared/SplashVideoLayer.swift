import SwiftUI
import AVKit

/// Full-bleed looping/play-once splash video. Muted by default (launch shouldn't
/// surprise users with sound). Falls back silently if the asset is missing.
struct SplashVideoLayer: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String
    var isMuted: Bool = true
    var onPlaybackFinished: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onPlaybackFinished = onPlaybackFinished
        return coordinator
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(to: view, name: resourceName, ext: fileExtension, muted: isMuted)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        context.coordinator.onPlaybackFinished = onPlaybackFinished
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    @MainActor
    final class Coordinator {
        var onPlaybackFinished: (() -> Void)?
        private var player: AVPlayer?
        private var endObserver: NSObjectProtocol?
        private var timeObserver: Any?

        func attach(to view: PlayerView, name: String, ext: String, muted: Bool) {
            teardown()
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                return
            }
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.isMuted = muted
            player.actionAtItemEnd = .pause
            view.playerLayer.player = player
            self.player = player

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.onPlaybackFinished?()
                }
            }

            player.play()
        }

        func teardown() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            player?.pause()
            player = nil
        }
    }
}
