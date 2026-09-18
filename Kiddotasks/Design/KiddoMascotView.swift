import SwiftUI

/// Playful reactions the Kiddo mascot can perform.
enum KiddoMascotMood: String, CaseIterable, Sendable {
    case idle
    case wave
    case thumbsUp
    case celebrate
    case thinking
    case run
    case sit

    var accessibilityLabel: String {
        switch self {
        case .idle: return "Kiddo mascot standing"
        case .wave: return "Kiddo mascot waving hello"
        case .thumbsUp: return "Kiddo mascot giving a thumbs up"
        case .celebrate: return "Kiddo mascot celebrating"
        case .thinking: return "Kiddo mascot thinking"
        case .run: return "Kiddo mascot running"
        case .sit: return "Kiddo mascot sitting"
        }
    }
}

/// Animated Kiddo mascot built from the character-sheet pose frames.
/// Idle/wave cycle frame sequences; other moods use a single pose with a gentle bob.
struct KiddoMascotView: View {
    /// Character height in points. Width follows the shared frame aspect.
    var size: CGFloat = 120
    var mood: KiddoMascotMood = .idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let idleFrames = [
        "kiddo_idle_0",
        "kiddo_idle_1",
        "kiddo_idle_2",
        "kiddo_idle_3"
    ]

    /// Full wave cycle from the character-sheet animation sequence.
    private static let waveFrames = [
        "kiddo_walk_0",
        "kiddo_walk_1",
        "kiddo_walk_2",
        "kiddo_walk_3",
        "kiddo_walk_4",
        "kiddo_walk_5",
        "kiddo_walk_6",
        "kiddo_walk_7"
    ]

    private var frames: [String] {
        switch mood {
        case .idle: return Self.idleFrames
        case .wave: return Self.waveFrames
        case .thumbsUp: return ["kiddo_pose_thumbs"]
        case .celebrate: return ["kiddo_pose_celebrate"]
        case .thinking: return ["kiddo_thinking"]
        case .run: return ["kiddo_pose_run"]
        case .sit: return ["kiddo_pose_sit"]
        }
    }

    private var frameDuration: TimeInterval {
        switch mood {
        case .wave: return 0.12
        case .idle: return 0.32
        case .run: return 0.18
        default: return 0.4
        }
    }

    /// Shared full-body canvas aspect (84×122 @1x). Thinking uses a square crop.
    private var aspectWidthOverHeight: CGFloat {
        mood == .thinking ? 1.0 : 84.0 / 122.0
    }

    private var displayWidth: CGFloat { size * aspectWidthOverHeight }

    var body: some View {
        Group {
            if reduceMotion {
                poseImage(named: frames[0])
            } else {
                TimelineView(.periodic(from: .now, by: frameDuration)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let index = Int(elapsed / frameDuration) % frames.count
                    // Soft vertical float so single-frame moods still feel alive.
                    let bob = sin(elapsed * .pi * 1.1) * (size * 0.018)
                    let celebratePop = mood == .celebrate
                        ? 1 + 0.03 * sin(elapsed * .pi * 1.6)
                        : 1.0

                    poseImage(named: frames[index])
                        .offset(y: bob)
                        .scaleEffect(celebratePop)
                }
            }
        }
        .frame(width: displayWidth, height: size, alignment: .bottom)
        .accessibilityLabel(mood.accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private func poseImage(named name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

/// Circular avatar chrome around the mascot — useful in headers and empty states.
struct KiddoMascotAvatarView: View {
    var size: CGFloat = 64
    var mood: KiddoMascotMood = .idle

    var body: some View {
        KiddoMascotView(size: size * 1.15, mood: mood)
            .frame(width: size, height: size, alignment: .center)
            .background {
                Circle()
                    .fill(KiddoTasksDesignTokens.Colors.primaryLight)
            }
            .overlay {
                Circle()
                    .strokeBorder(KiddoTasksDesignTokens.Colors.surfaceCard, lineWidth: max(1.5, size * 0.05))
            }
            .clipShape(Circle())
            .shadow(
                color: KiddoTasksDesignTokens.Colors.primary.opacity(0.22),
                radius: size * 0.08,
                x: 0,
                y: size * 0.04
            )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 28) {
            KiddoMascotView(size: 140, mood: .wave)
            KiddoMascotView(size: 120, mood: .idle)
            KiddoMascotView(size: 120, mood: .celebrate)
            HStack(spacing: 20) {
                KiddoMascotAvatarView(size: 72, mood: .idle)
                KiddoMascotAvatarView(size: 72, mood: .thumbsUp)
                KiddoMascotAvatarView(size: 72, mood: .thinking)
            }
        }
        .padding(24)
    }
    .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.welcome)
}
