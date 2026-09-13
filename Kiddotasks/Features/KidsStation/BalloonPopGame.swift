import SwiftUI

struct Balloon: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var color: Color
    var speed: CGFloat
    var wobble: CGFloat
    var popped = false
}

@MainActor
@Observable
final class BalloonPopEngine {
    var balloons: [Balloon] = []
    var scores: [Int] = [0, 0]
    var activeSide = 0 // 0 left, 1 right
    var targetScore = 10
    var isRunning = false
    var winner: Int?
    var popTick = 0
    var lastPoppedSide: Int?
    var lastPoppedId: UUID?

    private static let colors: [Color] = [
        Color(hex: "#D97868"),
        Color(hex: "#D59A3A"),
        Color(hex: "#3F8B70"),
        Color(hex: "#3978A8"),
        Color(hex: "#6F9FBD"),
    ]

    func start(playerCount: Int = 2) {
        scores = Array(repeating: 0, count: max(2, playerCount))
        activeSide = 0
        winner = nil
        balloons = []
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func spawn(in size: CGSize) {
        guard isRunning, winner == nil, size.width > 10 else { return }
        let side = Bool.random() ? 0 : 1
        let balloon = Balloon(
            x: side == 0 ? size.width * 0.25 : size.width * 0.75,
            y: size.height + 40,
            scale: CGFloat.random(in: 0.85...1.15),
            color: Self.colors.randomElement() ?? .red,
            speed: CGFloat.random(in: 75...130),
            wobble: CGFloat.random(in: 0...1)
        )
        balloons.append(balloon)
    }

    func step(dt: CGFloat, size: CGSize) {
        guard isRunning else { return }
        for i in balloons.indices {
            balloons[i].y -= balloons[i].speed * dt
            balloons[i].x += sin(balloons[i].y / 28 + balloons[i].wobble) * 0.35
        }
        balloons.removeAll { $0.y < -60 || $0.popped }
    }

    func pop(id: UUID, side: Int) {
        guard winner == nil, scores.indices.contains(side) else { return }
        guard let idx = balloons.firstIndex(where: { $0.id == id && !$0.popped }) else { return }
        balloons[idx].popped = true
        scores[side] += 1
        lastPoppedSide = side
        lastPoppedId = balloons[idx].id
        popTick += 1
        GameSounds.match()
        Haptic.light()
        if scores[side] >= targetScore {
            winner = side
            isRunning = false
            GameSounds.win()
            Haptic.success()
        }
    }
}

struct BalloonPopView: View {
    let players: [GamePlayer]
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = BalloonPopEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var confettiTick = 0
    @State private var spawnTask: Task<Void, Never>?
    @State private var stepTask: Task<Void, Never>?
    @State private var boardEntrance = false

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#D97868")
    }
    private var p2: GamePlayer {
        players.count > 1 ? players[1] : GamePlayer(displayName: "Player 2", colorHex: "#3978A8")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                ArcadeGameHeader(title: "Balloon Pop Race", emoji: "🎈", onExit: onExit)
                MultiplayerHUD(
                    players: [p1, p2],
                    activeIndex: engine.lastPoppedSide ?? 0,
                    scores: engine.scores,
                    turnLabel: "First to \(engine.targetScore) wins!"
                )
                playfield
                Spacer(minLength: 8)
                SecondaryButton(title: "End game") { finish() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if matchOver {
                GameResultView(
                    title: "🎉 You Win!",
                    message: "\(engine.winner == 0 ? p1.displayName : p2.displayName) popped the most!",
                    players: resultPlayers(),
                    winnerIds: [engine.winner == 0 ? p1.id : p2.id],
                    onRematch: {
                        matchOver = false
                        engine.start()
                        startLoop()
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            engine.start()
            startedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
            startLoop()
        }
        .onDisappear {
            engine.stop()
            spawnTask?.cancel()
            stepTask?.cancel()
        }
        .onChange(of: engine.winner) { _, w in
            guard w != nil else { return }
            confettiTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { record() }
        }
    }

    private func startLoop() {
        spawnTask?.cancel()
        stepTask?.cancel()
        spawnTask = Task { @MainActor in
            while !Task.isCancelled, engine.isRunning {
                try? await Task.sleep(nanoseconds: 900_000_000)
                // Size injected via a dummy; spawn uses last known from step
            }
        }
    }

    private var playfield: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Split lanes
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)

                ForEach(engine.balloons) { balloon in
                    if !balloon.popped {
                        Button {
                            let side = balloon.x < size.width * 0.5 ? 0 : 1
                            withAnimation(.easeOut(duration: 0.08)) {
                                engine.pop(id: balloon.id, side: side)
                            }
                        } label: {
                            ZStack {
                                Text("🎈")
                                    .font(.system(size: 48 * balloon.scale))
                                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                                if engine.lastPoppedId == balloon.id {
                                    Text("💥")
                                        .font(.system(size: 36))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(GameCellPressStyle())
                        .position(x: balloon.x, y: balloon.y)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(boardEntrance ? 1 : 0.95)
            .opacity(boardEntrance ? 1 : 0)
            .onAppear {
                startPhysics(size: size)
            }
            .onChange(of: size) { _, newSize in
                startPhysics(size: newSize)
            }
        }
        .padding(.horizontal, 8)
    }

    private func startPhysics(size: CGSize) {
        spawnTask?.cancel()
        stepTask?.cancel()
        guard size.width > 10 else { return }

        spawnTask = Task { @MainActor in
            while !Task.isCancelled, engine.isRunning {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 350_000_000...650_000_000))
                engine.spawn(in: size)
            }
        }
        stepTask = Task { @MainActor in
            while !Task.isCancelled, engine.isRunning {
                engine.step(dt: 1.0 / 30.0, size: size)
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = engine.scores.indices.contains(0) ? engine.scores[0] : 0
        var b = p2
        b.score = engine.scores.indices.contains(1) ? engine.scores[1] : 0
        return [a, b]
    }

    private func record() {
        let winnerSide = engine.winner ?? 0
        GameStatsStore.shared.record(
            gameId: .balloon,
            players: resultPlayers(),
            winnerIds: [winnerSide == 0 ? p1.id : p2.id],
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private func finish() {
        engine.stop()
        if engine.winner == nil {
            // Higher score wins if abandoned
            let s = engine.scores
            if s.indices.contains(0), s.indices.contains(1) {
                if s[0] != s[1] {
                    engine.winner = s[0] > s[1] ? 0 : 1
                }
            }
        }
        if engine.winner != nil {
            confettiTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { record() }
        } else {
            onExit()
        }
    }
}
