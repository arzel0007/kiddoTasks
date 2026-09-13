import SwiftUI

@MainActor
@Observable
final class TicTacToeEngine {
    enum Cell: Equatable { case empty, x, o }
    enum Outcome: Equatable { case none, xWins, oWins, draw }

    var board: [[Cell]] = Array(repeating: Array(repeating: .empty, count: 3), count: 3)
    var isXTurn = true
    var outcome: Outcome = .none
    var xScore = 0
    var oScore = 0
    /// Winning line cells for celebration highlight.
    var winningCells: [(Int, Int)] = []
    /// Bumped when a mark is placed (for animation triggers).
    var lastPlaced: (row: Int, col: Int)?
    var placementTick = 0

    func resetBoard() {
        board = Array(repeating: Array(repeating: .empty, count: 3), count: 3)
        isXTurn = true
        outcome = .none
        winningCells = []
        lastPlaced = nil
    }

    @discardableResult
    func tap(row: Int, col: Int) -> Bool {
        guard outcome == .none, board[row][col] == .empty else { return false }
        board[row][col] = isXTurn ? .x : .o
        lastPlaced = (row, col)
        placementTick += 1
        evaluate()
        if outcome == .none {
            isXTurn.toggle()
        }
        return true
    }

    private func evaluate() {
        let lines: [[(Int, Int)]] = [
            [(0,0),(0,1),(0,2)], [(1,0),(1,1),(1,2)], [(2,0),(2,1),(2,2)],
            [(0,0),(1,0),(2,0)], [(0,1),(1,1),(2,1)], [(0,2),(1,2),(2,2)],
            [(0,0),(1,1),(2,2)], [(0,2),(1,1),(2,0)],
        ]
        for line in lines {
            let vals = line.map { board[$0.0][$0.1] }
            if vals[0] == .x && vals[1] == .x && vals[2] == .x {
                outcome = .xWins
                winningCells = line
                xScore += 1
                GameSounds.win()
                Haptic.success()
                return
            }
            if vals[0] == .o && vals[1] == .o && vals[2] == .o {
                outcome = .oWins
                winningCells = line
                oScore += 1
                GameSounds.win()
                Haptic.success()
                return
            }
        }
        if board.flatMap({ $0 }).allSatisfy({ $0 != .empty }) {
            outcome = .draw
            GameSounds.draw()
            Haptic.light()
        }
    }
}

struct TicTacToeView: View {
    let players: [GamePlayer]
    var requirePassDevice = true
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var engine = TicTacToeEngine()
    @State private var showPass = false
    @State private var matchOver = false
    @State private var startedAt = Date()

    // FX state
    @State private var boardEntrance = false
    @State private var markProgress: [String: CGFloat] = [:]
    @State private var invalidCell: String?
    @State private var winLineProgress: CGFloat = 0
    @State private var boardPulse = false
    @State private var confettiTick = 0
    @State private var scorePopTick = 0
    @State private var celebrateTick = 0

    private func key(_ r: Int, _ c: Int) -> String { "\(r)-\(c)" }

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#3978A8", symbol: "✕")
    }
    private var p2: GamePlayer {
        players.count > 1
            ? players[1]
            : GamePlayer(displayName: "Player 2", colorHex: "#3F8B70", symbol: "○")
    }
    private var currentName: String { engine.isXTurn ? p1.displayName : p2.displayName }
    private var currentColor: String { engine.isXTurn ? p1.colorHex : p2.colorHex }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                header
                statusLine
                boardView
                Spacer(minLength: 8)
                if engine.outcome != .none {
                    PrimaryButton(title: engine.xScore + engine.oScore >= 3 ? "New match" : "Next round") {
                        GameSounds.restart()
                        nextRound()
                    }
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                }
                SecondaryButton(title: "End game") { finishMatch() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            ScorePopView(text: "⭐ Nice!", trigger: scorePopTick)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 80)

            if showPass {
                PassDeviceCard(playerName: passName(), colorHex: passColor()) {
                    showPass = false
                }
                .transition(.opacity)
            }

            if matchOver {
                GameResultView(
                    title: engine.xScore == engine.oScore ? "Great match!" : "Nice game!",
                    message: "\(p1.displayName) \(engine.xScore) — \(engine.oScore) \(p2.displayName)",
                    players: resultPlayers(),
                    winnerIds: engine.xScore == engine.oScore ? [] : (engine.xScore > engine.oScore ? [p1.id] : [p2.id]),
                    onRematch: {
                        matchOver = false
                        engine.xScore = 0
                        engine.oScore = 0
                        engine.resetBoard()
                        resetFX()
                        boardEntrance = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showPass)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            if reduceMotion {
                boardEntrance = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.68).delay(0.05)) {
                    boardEntrance = true
                }
            }
        }
    }

    private func resetFX() {
        markProgress = [:]
        winLineProgress = 0
        boardPulse = false
        invalidCell = nil
    }

    private func nextRound() {
        withAnimation(.easeIn(duration: 0.18)) {
            boardEntrance = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            engine.resetBoard()
            resetFX()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                boardEntrance = true
            }
        }
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = engine.xScore
        var b = p2
        b.score = engine.oScore
        return [a, b]
    }

    private func passName() -> String { engine.isXTurn ? p1.displayName : p2.displayName }
    private func passColor() -> String { engine.isXTurn ? p1.colorHex : p2.colorHex }

    private func finishMatch() {
        let winnerIds: [String] = engine.xScore == engine.oScore
            ? []
            : (engine.xScore > engine.oScore ? [p1.id] : [p2.id])
        GameStatsStore.shared.record(
            gameId: .tictactoe,
            players: resultPlayers(),
            winnerIds: winnerIds,
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🎮 Tic-Tac-Toe")
                    .font(KiddoTasksDesignTokens.Typography.headingMedium)
                Text("Best of 3 rounds")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            if engine.outcome == .none {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: currentColor)).frame(width: 14, height: 14)
                    Text(currentName)
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.92)))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.isXTurn)
    }

    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 10
            let cell = (side - gap * 2) / 3

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(0..<3, id: \.self) { c in
                                cellView(r: r, c: c, cell: cell)
                                    .scaleEffect(boardEntrance ? 1 : 0.6)
                                    .opacity(boardEntrance ? 1 : 0)
                                    .animation(
                                        reduceMotion
                                            ? .default
                                            : .spring(response: 0.38, dampingFraction: 0.62)
                                                .delay(Double(r * 3 + c) * 0.04),
                                        value: boardEntrance
                                    )
                            }
                        }
                    }
                }
                .scaleEffect(boardPulse && !reduceMotion ? 1.03 : 1)

                // Winning line overlay
                if !engine.winningCells.isEmpty, winLineProgress > 0 {
                    WinLineOverlay(
                        cells: engine.winningCells,
                        progress: winLineProgress,
                        side: side,
                        gap: gap
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func cellView(r: Int, c: Int, cell: CGFloat) -> some View {
        let k = key(r, c)
        let cellValue = engine.board[r][c]
        let isWin = engine.winningCells.contains { $0.0 == r && $0.1 == c }
        let color = cellValue == .x ? Color(hex: p1.colorHex) : Color(hex: p2.colorHex)

        return Button {
            handleTap(r: r, c: c)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: max(14, cell * 0.18), style: .continuous)
                    .fill(
                        isWin
                            ? KiddoTasksDesignTokens.Colors.successLight
                            : KiddoTasksDesignTokens.Colors.surfaceCard
                    )
                    .shadow(
                        color: Color.black.opacity(isWin ? 0.08 : 0.05),
                        radius: isWin ? 8 : 3,
                        y: isWin ? 3 : 2
                    )

                if cellValue != .empty {
                    markView(cellValue, color: color, size: cell, isWin: isWin, k: k)
                }
            }
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: max(14, cell * 0.18), style: .continuous)
                    .strokeBorder(
                        cellValue == .empty ? Color.clear : color.opacity(0.35),
                        lineWidth: 2
                    )
            )
            .scaleEffect(invalidCell == k && !reduceMotion ? 0.92 : 1)
            .offset(x: invalidCell == k && !reduceMotion ? shakeOffset : 0)
        }
        .buttonStyle(GameCellPressStyle())
        .disabled(engine.outcome != .none || cellValue != .empty)
        .accessibilityLabel(cellValue == .x ? "X" : cellValue == .o ? "O" : "Empty")
    }

    @State private var shakeOffset: CGFloat = 0

    private func markView(
        _ cell: TicTacToeEngine.Cell,
        color: Color,
        size: CGFloat,
        isWin: Bool,
        k: String
    ) -> some View {
        let lineWidth = max(6, size * 0.08)
        return ZStack {
            if cell == .x {
                XMarkShape(progress: markProgress[k] ?? 1)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            } else {
                OMarkShape(progress: markProgress[k] ?? 1)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
        .padding(size * 0.16)
        .scaleEffect(isWin && !reduceMotion ? winBounceScale : 1)
    }

    @State private var winBounceScale: CGFloat = 1

    private func handleTap(r: Int, c: Int) {
        let k = key(r, c)
        guard engine.outcome == .none else { return }
        if engine.board[r][c] != .empty {
            // Invalid — playful shake
            GameSounds.miss()
            invalidCell = k
            withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) { shakeOffset = -6 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) { shakeOffset = 6 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) { shakeOffset = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { invalidCell = nil }
            return
        }

        GameSounds.tap()
        let placed = engine.tap(row: r, col: c)
        guard placed else { return }
        GameSounds.place()

        // Draw-on mark
        if reduceMotion {
            markProgress[k] = 1
        } else {
            markProgress[k] = 0
            withAnimation(.easeOut(duration: 0.32)) { markProgress[k] = 1 }
        }

        if engine.outcome != .none {
            celebrateRound()
        } else if requirePassDevice {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                showPass = true
            }
        }
    }

    private func celebrateRound() {
        celebrateTick += 1
        confettiTick += 1
        scorePopTick += 1

        if reduceMotion {
            winLineProgress = 1
            return
        }

        withAnimation(.easeInOut(duration: 0.25).delay(0.15)) {
            winLineProgress = 1
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55).delay(0.2)) {
            boardPulse = true
            winBounceScale = 1.12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                boardPulse = false
                winBounceScale = 1
            }
        }
    }

    private var statusLine: some View {
        VStack(spacing: 4) {
            Text(statusText)
                .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                .fontWeight(.semibold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                .id(statusText)
                .transition(.opacity)
            Text("\(p1.displayName) \(engine.xScore) · \(p2.displayName) \(engine.oScore)")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .scaleEffect(scorePopTick > 0 && !reduceMotion ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: scorePopTick)
        }
        .padding(.horizontal, 20)
    }

    private var statusText: String {
        switch engine.outcome {
        case .none: return "\(currentName)'s turn"
        case .xWins: return "\(p1.displayName) wins the round! 🎉"
        case .oWins: return "\(p2.displayName) wins the round! 🎉"
        case .draw: return "It's a draw! 🤝"
        }
    }
}

// MARK: - Win line

private struct WinLineOverlay: View {
    let cells: [(Int, Int)]
    let progress: CGFloat
    let side: CGFloat
    let gap: CGFloat

    private func center(_ r: Int, _ c: Int) -> CGPoint {
        let cell = (side - gap * 2) / 3
        return CGPoint(
            x: CGFloat(c) * (cell + gap) + cell / 2,
            y: CGFloat(r) * (cell + gap) + cell / 2
        )
    }

    var body: some View {
        let first = cells.first ?? (0, 0)
        let last = cells.last ?? (0, 0)
        let a = center(first.0, first.1)
        let b = center(last.0, last.1)

        Path { p in
            p.move(to: a)
            p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * progress, y: a.y + (b.y - a.y) * progress))
        }
        .stroke(
            Color(hex: "#D59A3A").opacity(0.85),
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )
        .frame(width: side, height: side)
    }
}

// MARK: - Cell press style (bouncy)

struct GameCellPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
