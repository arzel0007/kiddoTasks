import SwiftUI

// MARK: - Engine

@MainActor
@Observable
final class SnakesLaddersEngine {
    static let boardSize = 100
    static let ladders: [Int: Int] = [
        4: 14, 9: 31, 20: 38, 28: 84,
        40: 59, 51: 67, 63: 81, 71: 91,
    ]
    static let snakes: [Int: Int] = [
        17: 7, 54: 34, 62: 19, 64: 60,
        87: 24, 93: 73, 95: 75, 98: 78,
    ]

    var positions: [Int] = []
    var turnIndex = 0
    var dice = 1
    var isRolling = false
    var isMoving = false
    var winnerIndex: Int?
    var banner: String?
    var hopTick = 0

    func start(playerCount: Int) {
        positions = Array(repeating: 0, count: max(2, playerCount))
        turnIndex = 0
        dice = 1
        isRolling = false
        isMoving = false
        winnerIndex = nil
        banner = nil
        hopTick = 0
    }

    func beginRoll() -> Int {
        guard !isRolling, !isMoving, winnerIndex == nil else { return 0 }
        isRolling = true
        let value = Int.random(in: 1...6)
        dice = value
        return value
    }

    func endRollAnimation() {
        isRolling = false
    }

    /// Moves one square at a time so tokens visibly hop.
    func moveSteps(_ steps: Int) async {
        guard winnerIndex == nil, positions.indices.contains(turnIndex) else {
            isMoving = false
            return
        }
        isMoving = true
        banner = nil
        var remaining = steps
        while remaining > 0, winnerIndex == nil {
            var next = positions[turnIndex] + 1
            if next > Self.boardSize {
                next = Self.boardSize - (next - Self.boardSize)
            }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                positions[turnIndex] = next
                hopTick += 1
            }
            Haptic.light()
            try? await Task.sleep(nanoseconds: 160_000_000)
            remaining -= 1
            if positions[turnIndex] >= Self.boardSize { break }
        }

        // Snake / ladder after landing
        let landed = positions[turnIndex]
        if let dest = Self.ladders[landed] {
            banner = "🚀 BONUS CLIMB!"
            GameSounds.win()
            Haptic.success()
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                positions[turnIndex] = dest
                hopTick += 1
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
        } else if let dest = Self.snakes[landed] {
            banner = "🐍 Oops!"
            GameSounds.miss()
            Haptic.light()
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                positions[turnIndex] = dest
                hopTick += 1
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }

        if positions[turnIndex] >= Self.boardSize {
            winnerIndex = turnIndex
            banner = "🏆 WINNER!"
            GameSounds.win()
            Haptic.success()
            isMoving = false
            return
        }

        if steps == 6 {
            banner = "🎲 Roll again!"
        } else {
            turnIndex = (turnIndex + 1) % positions.count
            banner = nil
        }
        isMoving = false
    }
}

// MARK: - View

struct SnakesLaddersView: View {
    let players: [GamePlayer]
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = SnakesLaddersEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var diceSpin = 0.0
    @State private var dicePop = false
    @State private var confettiTick = 0
    @State private var boardEntrance = false
    @State private var rollTask: Task<Void, Never>?

    private var p: [GamePlayer] {
        players.isEmpty
            ? [GamePlayer(displayName: "P1"), GamePlayer(displayName: "P2", colorHex: "#D97868")]
            : players
    }

    private var activeName: String {
        let i = min(max(engine.turnIndex, 0), max(p.count - 1, 0))
        return p[i].displayName
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ArcadeGameHeader(title: "Snakes & Ladders", emoji: "🐍", onExit: onExit)
                MultiplayerHUD(
                    players: p,
                    activeIndex: min(engine.turnIndex, max(p.count - 1, 0)),
                    scores: engine.positions,
                    turnLabel: engine.winnerIndex == nil
                        ? (engine.isMoving ? "\(activeName) is moving…" : "\(activeName)'s turn")
                        : nil
                )
                if let banner = engine.banner {
                    Text(banner)
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                        .id(banner)
                        .transition(.scale.combined(with: .opacity))
                }
                boardView
                diceBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if matchOver {
                GameResultView(
                    title: "🏆 Winner!",
                    message: "\(p[min(engine.winnerIndex ?? 0, max(p.count - 1, 0))].displayName) reached the finish!",
                    players: scoredPlayers(),
                    winnerIds: engine.winnerIndex.map { [p[min($0, max(p.count - 1, 0))].id] } ?? [],
                    onRematch: {
                        matchOver = false
                        engine.start(playerCount: p.count)
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.banner)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            engine.start(playerCount: p.count)
            startedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
        }
        .onChange(of: engine.winnerIndex) { _, winner in
            guard winner != nil else { return }
            confettiTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                recordAndFinish()
            }
        }
        .onDisappear { rollTask?.cancel() }
    }

    private func scoredPlayers() -> [GamePlayer] {
        p.enumerated().map { i, player in
            var copy = player
            copy.score = engine.positions.indices.contains(i) ? engine.positions[i] : 0
            return copy
        }
    }

    private func recordAndFinish() {
        let winnerIds = engine.winnerIndex.map { [p[min($0, max(p.count - 1, 0))].id] } ?? []
        GameStatsStore.shared.record(
            gameId: .snakes,
            players: scoredPlayers(),
            winnerIds: winnerIds,
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 10

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for n in 1...100 {
                        let (col, row) = Self.colRow(for: n)
                        let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        let fill = n % 2 == 0 ? Color(hex: "#E7F1F8") : Color.white
                        context.fill(
                            Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3),
                            with: .color(fill)
                        )
                        if n == 1 || n == 100 || n % 5 == 0 {
                            let text = Text("\(n)")
                                .font(.system(size: max(6, cell * 0.26), weight: .bold, design: .rounded))
                                .foregroundColor(KiddoTasksDesignTokens.Colors.textSecondary)
                            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
                        }
                    }
                    // Ladders first (under snakes)
                    for (start, end) in SnakesLaddersEngine.ladders {
                        drawLadder(context: context, from: start, to: end, cell: cell)
                    }
                    // Snakes on top
                    for (start, end) in SnakesLaddersEngine.snakes {
                        drawSnake(context: context, from: start, to: end, cell: cell)
                    }
                }

                // Tokens — use .position (center in board space), NOT .offset
                ForEach(Array(p.enumerated()), id: \.element.id) { index, player in
                    let pos = engine.positions.indices.contains(index) ? max(engine.positions[index], 1) : 1
                    let (col, row) = Self.colRow(for: pos)
                    let stackX = CGFloat(index % 2) * cell * 0.28 - cell * 0.07
                    let stackY = CGFloat(index / 2) * cell * 0.18 - cell * 0.05
                    let tokenSize = max(16, cell * 0.52)

                    PlayerTokenView(player: player, size: tokenSize)
                        .position(
                            x: CGFloat(col) * cell + cell / 2 + stackX,
                            y: CGFloat(row) * cell + cell / 2 + stackY
                        )
                        .scaleEffect(engine.hopTick > 0 && index == engine.turnIndex ? 1.14 : 1)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pos)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: engine.hopTick)
                        .zIndex(Double(index))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(boardEntrance ? 1 : 0.92)
            .opacity(boardEntrance ? 1 : 0)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private func center(_ n: Int, cell: CGFloat) -> CGPoint {
        let (col, row) = Self.colRow(for: n)
        return CGPoint(x: CGFloat(col) * cell + cell / 2, y: CGFloat(row) * cell + cell / 2)
    }

    /// Wooden ladder: two rails + rungs.
    private func drawLadder(context: GraphicsContext, from: Int, to: Int, cell: CGFloat) {
        let a = center(from, cell: cell)
        let b = center(to, cell: cell)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 1)
        let nx = -dy / len
        let ny = dx / len
        let half = cell * 0.22

        let railA1 = CGPoint(x: a.x + nx * half, y: a.y + ny * half)
        let railA2 = CGPoint(x: a.x - nx * half, y: a.y - ny * half)
        let railB1 = CGPoint(x: b.x + nx * half, y: b.y + ny * half)
        let railB2 = CGPoint(x: b.x - nx * half, y: b.y - ny * half)

        var rail1 = Path()
        rail1.move(to: railA1)
        rail1.addLine(to: railB1)
        var rail2 = Path()
        rail2.move(to: railA2)
        rail2.addLine(to: railB2)

        let railColor = Color(hex: "#A67C52")
        let rungColor = Color(hex: "#C4A574")
        let railW = max(2.5, cell * 0.09)
        context.stroke(rail1, with: .color(railColor), style: StrokeStyle(lineWidth: railW, lineCap: .round))
        context.stroke(rail2, with: .color(railColor), style: StrokeStyle(lineWidth: railW, lineCap: .round))

        let rungCount = max(3, Int(len / (cell * 0.45)))
        for i in 1..<rungCount {
            let t = CGFloat(i) / CGFloat(rungCount)
            let cx = a.x + dx * t
            let cy = a.y + dy * t
            var rung = Path()
            rung.move(to: CGPoint(x: cx + nx * half, y: cy + ny * half))
            rung.addLine(to: CGPoint(x: cx - nx * half, y: cy - ny * half))
            context.stroke(rung, with: .color(rungColor), style: StrokeStyle(lineWidth: max(2, cell * 0.07), lineCap: .round))
        }

        // Start / end badges
        let up = Text("🪜")
            .font(.system(size: max(10, cell * 0.32)))
        context.draw(up, at: CGPoint(x: a.x, y: a.y - cell * 0.05))
    }

    /// Snake: wavy body + head at the high square (slides down to tail).
    private func drawSnake(context: GraphicsContext, from: Int, to: Int, cell: CGFloat) {
        // from = head (high), to = tail (low)
        let head = center(from, cell: cell)
        let tail = center(to, cell: cell)

        let dx = tail.x - head.x
        let dy = tail.y - head.y
        let len = max(sqrt(dx * dx + dy * dy), 1)
        let ux = dx / len
        let uy = dy / len
        let nx = -uy
        let ny = ux

        var path = Path()
        path.move(to: head)
        let steps = 16
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let wave = sin(t * .pi * 3) * cell * 0.28
            let x = head.x + dx * t + nx * wave
            let y = head.y + dy * t + ny * wave
            path.addLine(to: CGPoint(x: x, y: y))
        }

        context.stroke(
            path,
            with: .color(Color(hex: "#3F8B70")),
            style: StrokeStyle(lineWidth: max(4, cell * 0.16), lineCap: .round, lineJoin: .round)
        )
        // Belly stripe
        context.stroke(
            path,
            with: .color(Color(hex: "#7BC49A").opacity(0.45)),
            style: StrokeStyle(lineWidth: max(2, cell * 0.06), lineCap: .round)
        )

        // Head + tail markers
        let headEmoji = Text("🐍").font(.system(size: max(12, cell * 0.38)))
        context.draw(headEmoji, at: CGPoint(x: head.x, y: head.y - cell * 0.02))
        let tailDot = CGRect(
            x: tail.x - cell * 0.1,
            y: tail.y - cell * 0.1,
            width: cell * 0.2,
            height: cell * 0.2
        )
        context.fill(Path(ellipseIn: tailDot), with: .color(Color(hex: "#2E6B52")))
    }

    static func colRow(for n: Int) -> (col: Int, row: Int) {
        let idx = max(0, min(99, n - 1))
        let rowFromBottom = idx / 10
        let colInRow = idx % 10
        let col = rowFromBottom % 2 == 0 ? colInRow : 9 - colInRow
        let row = 9 - rowFromBottom
        return (col, row)
    }

    private var diceBar: some View {
        HStack(spacing: 12) {
            Text(diceFace)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .rotationEffect(.degrees(diceSpin))
                .scaleEffect(dicePop ? 1.12 : 1)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            Button {
                rollDice()
            } label: {
                Text(engine.isRolling || engine.isMoving ? "…" : "🎲 ROLL")
                    .font(KiddoTasksDesignTokens.Typography.titleMedium)
                    .fontWeight(.heavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(KiddoTasksDesignTokens.Colors.primary)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(GameCellPressStyle())
            .disabled(engine.isRolling || engine.isMoving || engine.winnerIndex != nil)
            .opacity(engine.isRolling || engine.isMoving || engine.winnerIndex != nil ? 0.45 : 1)

            Button {
                GameSounds.restart()
                rollTask?.cancel()
                engine.start(playerCount: p.count)
                startedAt = Date()
            } label: {
                Text("↻")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(KiddoTasksDesignTokens.Colors.surfaceCard))
            }
            .buttonStyle(GameCellPressStyle())
            .accessibilityLabel("Restart game")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var diceFace: String {
        ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"][max(0, min(5, engine.dice - 1))]
    }

    private func rollDice() {
        guard !engine.isRolling, !engine.isMoving, engine.winnerIndex == nil else { return }
        GameSounds.tap()
        let value = engine.beginRoll()
        guard value > 0 else { return }

        rollTask = Task { @MainActor in
            if reduceMotion {
                engine.endRollAnimation()
                await engine.moveSteps(value)
                return
            }
            for _ in 0..<7 {
                withAnimation(.linear(duration: 0.04)) { diceSpin += 90 }
                engine.dice = Int.random(in: 1...6)
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            engine.dice = value
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { dicePop = true }
            GameSounds.place()
            try? await Task.sleep(nanoseconds: 180_000_000)
            dicePop = false
            engine.endRollAnimation()
            await engine.moveSteps(value)
        }
    }
}

/// Board token: real kid avatar when linked, else colored initial chip.
private struct PlayerTokenView: View {
    @Environment(AppState.self) private var appState
    let player: GamePlayer
    let size: CGFloat

    private var child: Child? {
        guard let id = player.childId else { return nil }
        return appState.child(id: id)
    }

    var body: some View {
        if let child {
            ChildAvatarView(
                avatar: child.avatar,
                size: size,
                photoData: child.photoData,
                photoURL: child.photoURL
            )
        } else {
            Circle()
                .fill(Color(hex: player.colorHex).opacity(0.28))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(player.displayName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: player.colorHex))
                )
                .overlay(
                    Circle().strokeBorder(KiddoTasksDesignTokens.Colors.surfaceCard, lineWidth: 2)
                )
        }
    }
}
