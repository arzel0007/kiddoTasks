import SwiftUI

// MARK: - Engine

@MainActor
@Observable
final class WhackAMoleEngine {
    struct Hole: Identifiable {
        let id: Int
        var isUp = false
        var isHit = false
        var isBad = false
        var glyph = "🐹"
    }

    static let holeCount = 9
    static let turnSeconds: TimeInterval = 15

    var holes: [Hole] = (0..<holeCount).map { Hole(id: $0) }
    var turnIndex = 0
    var scores: [Int] = [0, 0]
    var timeLeft = turnSeconds
    var isRunning = false
    var winner: Int?
    var popTick = 0
    var roundBanner: String?
    var flashText: String?
    var flashTick = 0

    private var spawnTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?

    private static let goodFaces = ["🐹", "🐰", "🐸", "🐻", "🦊", "🐼"]
    private static let badFaces = ["🐍", "☠️", "💣"]

    func start(playerCount: Int = 2) {
        stopTimers()
        scores = Array(repeating: 0, count: max(2, playerCount))
        turnIndex = 0
        winner = nil
        timeLeft = Self.turnSeconds
        holes = (0..<Self.holeCount).map { Hole(id: $0) }
        isRunning = true
        roundBanner = nil
        flashText = nil
        startSpawning()
        startClock()
    }

    func stop() {
        isRunning = false
        stopTimers()
        for i in holes.indices {
            holes[i].isUp = false
            holes[i].isHit = false
        }
    }

    func nextTurn() {
        guard winner == nil else { return }
        for i in holes.indices {
            holes[i].isUp = false
            holes[i].isHit = false
        }
        turnIndex = (turnIndex + 1) % scores.count
        timeLeft = Self.turnSeconds
        roundBanner = nil
        flashText = nil
        isRunning = true
        startSpawning()
        startClock()
    }

    func whack(index: Int) {
        guard isRunning, winner == nil, holes.indices.contains(index) else { return }
        if holes[index].isUp {
            let wasBad = holes[index].isBad
            let glyph = holes[index].glyph
            holes[index].isUp = false
            holes[index].isHit = true
            if wasBad {
                scores[turnIndex] = max(0, scores[turnIndex] - 2)
                flashText = "\(glyph) −2"
                GameSounds.miss()
                Haptic.warning()
            } else {
                scores[turnIndex] += 1
                flashText = "\(glyph) +1"
                GameSounds.match()
                Haptic.light()
            }
            popTick += 1
            flashTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self, self.holes.indices.contains(index) else { return }
                self.holes[index].isHit = false
            }
        } else {
            flashText = "💨"
            flashTick += 1
            GameSounds.miss()
        }
    }

    private func startSpawning() {
        spawnTask?.cancel()
        spawnTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRunning, self.winner == nil {
                // Faster cadence
                let delay = UInt64.random(in: 220_000_000...480_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard self.isRunning, self.winner == nil else { return }
                let down = self.holes.indices.filter { !self.holes[$0].isUp }
                // Spawn 1–2 at once for pace
                let count = min(down.count, Int.random(in: 1...2))
                guard count > 0, let _ = down.randomElement() else { continue }
                var picks = down.shuffled().prefix(count)
                for pick in picks {
                    let isBad = Int.random(in: 0..<5) == 0 // ~20% bad
                    self.holes[pick].isBad = isBad
                    self.holes[pick].glyph = isBad
                        ? (Self.badFaces.randomElement() ?? "🐍")
                        : (Self.goodFaces.randomElement() ?? "🐹")
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                        self.holes[pick].isUp = true
                    }
                }
                let upTime = UInt64.random(in: 450_000_000...900_000_000)
                try? await Task.sleep(nanoseconds: upTime)
                for pick in picks {
                    guard self.holes.indices.contains(pick), self.holes[pick].isUp else { continue }
                    withAnimation(.easeIn(duration: 0.12)) {
                        self.holes[pick].isUp = false
                    }
                }
                picks = []
            }
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRunning, self.winner == nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard self.isRunning else { return }
                self.timeLeft -= 1
                if self.timeLeft <= 0 {
                    self.timeLeft = 0
                    self.isRunning = false
                    self.stopTimers()
                    for i in self.holes.indices { self.holes[i].isUp = false }
                    if self.turnIndex >= self.scores.count - 1 {
                        let maxScore = self.scores.max() ?? 0
                        let winners = self.scores.enumerated().filter { $0.element == maxScore }.map(\.offset)
                        if winners.count == 1 {
                            self.winner = winners[0]
                            self.roundBanner = "🏆 WINNER!"
                            GameSounds.win()
                            Haptic.success()
                        } else {
                            self.winner = -1
                            self.roundBanner = "🤝 Tie!"
                            GameSounds.draw()
                        }
                    } else {
                        self.roundBanner = "Pass the device!"
                    }
                    return
                }
            }
        }
    }

    private func stopTimers() {
        spawnTask?.cancel()
        clockTask?.cancel()
        spawnTask = nil
        clockTask = nil
    }
}

// MARK: - View

struct WhackAMoleView: View {
    let players: [GamePlayer]
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = WhackAMoleEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var confettiTick = 0
    @State private var boardEntrance = false

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#8B6B4A")
    }
    private var p2: GamePlayer {
        players.count > 1 ? players[1] : GamePlayer(displayName: "Player 2", colorHex: "#3F8B70")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ArcadeGameHeader(title: "Whack-a-Mole", emoji: "🔨", onExit: onExit)
                MultiplayerHUD(
                    players: [p1, p2],
                    activeIndex: min(engine.turnIndex, 1),
                    scores: engine.scores,
                    turnLabel: engine.isRunning
                        ? "\(engine.turnIndex == 0 ? p1.displayName : p2.displayName) · \(Int(engine.timeLeft))s"
                        : engine.roundBanner
                )
                Text("Whack friends (+1) · avoid 🐍☠️💣 (−2)")
                    .font(KiddoTasksDesignTokens.Typography.captionSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)

                if let flash = engine.flashText {
                    Text(flash)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .id(engine.flashTick)
                        .transition(.scale.combined(with: .opacity))
                }

                boardView
                Spacer(minLength: 6)
                if !engine.isRunning, engine.winner == nil, engine.roundBanner == "Pass the device!" {
                    PrimaryButton(title: "Next player — I'm ready") {
                        engine.nextTurn()
                    }
                    .padding(.horizontal, 20)
                }
                SecondaryButton(title: "End game") { finish() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if matchOver {
                GameResultView(
                    title: engine.winner == -1 ? "🤝 Tie!" : "🎉 You Win!",
                    message: "\(p1.displayName) \(engine.scores[safe: 0] ?? 0) — \(engine.scores[safe: 1] ?? 0) \(p2.displayName)",
                    players: resultPlayers(),
                    winnerIds: winnerIds(),
                    onRematch: {
                        matchOver = false
                        engine.start()
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.flashTick)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            engine.start()
            startedAt = Date()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { boardEntrance = true }
        }
        .onDisappear { engine.stop() }
        .onChange(of: engine.winner) { _, w in
            guard w != nil else { return }
            if w != -1 { confettiTick += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { record() }
        }
    }

    private var boardView: some View {
        GeometryReader { geo in
            let cols = 3
            let spacing: CGFloat = 8
            let side = min(geo.size.width, geo.size.height)
            let hole = max((side - spacing * CGFloat(cols - 1)) / CGFloat(cols), 56)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(hole), spacing: spacing), count: cols),
                spacing: spacing
            ) {
                ForEach(engine.holes) { holeModel in
                    Button {
                        engine.whack(index: holeModel.id)
                    } label: {
                        ZStack {
                            Ellipse()
                                .fill(Color(hex: "#5C4033").opacity(0.4))
                                .frame(width: hole, height: hole * 0.5)
                                .offset(y: hole * 0.2)
                            if holeModel.isUp {
                                Text(holeModel.glyph)
                                    .font(.system(size: hole * 0.52))
                                    .offset(y: -hole * 0.06)
                                    .transition(.scale(scale: 0.3).combined(with: .move(edge: .bottom)))
                            }
                            if holeModel.isHit {
                                Text("💥")
                                    .font(.system(size: hole * 0.45))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: hole, height: hole)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(GameCellPressStyle())
                    .scaleEffect(boardEntrance ? 1 : 0.7)
                    .opacity(boardEntrance ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? .default
                            : .spring(response: 0.3, dampingFraction: 0.65)
                                .delay(Double(holeModel.id) * 0.025),
                        value: boardEntrance
                    )
                    .animation(.spring(response: 0.22, dampingFraction: 0.55), value: holeModel.isHit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = engine.scores[safe: 0] ?? 0
        var b = p2
        b.score = engine.scores[safe: 1] ?? 0
        return [a, b]
    }

    private func winnerIds() -> [String] {
        guard let w = engine.winner, w >= 0 else { return [] }
        return [w == 0 ? p1.id : p2.id]
    }

    private func record() {
        GameStatsStore.shared.record(
            gameId: .whack,
            players: resultPlayers(),
            winnerIds: winnerIds(),
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private func finish() {
        engine.stop()
        if engine.winner == nil {
            let s = engine.scores
            if s.count >= 2, s[0] != s[1] {
                engine.winner = s[0] > s[1] ? 0 : 1
            } else {
                engine.winner = -1
            }
        }
        confettiTick += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { record() }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
