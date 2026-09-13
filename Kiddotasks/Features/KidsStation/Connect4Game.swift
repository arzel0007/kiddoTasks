import SwiftUI

@MainActor
@Observable
final class Connect4Engine {
    static let rows = 6
    static let cols = 7

    /// 0 empty, 1 = P1, 2 = P2
    var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: cols), count: rows)
    var turn = 1
    var winner: Int?
    var winningCells: [(Int, Int)] = []
    var dropColumn: Int?
    var dropRow: Int?
    var dropTick = 0

    func reset() {
        grid = Array(repeating: Array(repeating: 0, count: Self.cols), count: Self.rows)
        turn = 1
        winner = nil
        winningCells = []
        dropColumn = nil
        dropRow = nil
    }

    @discardableResult
    func drop(col: Int) -> Bool {
        guard winner == nil, col >= 0, col < Self.cols else { return false }
        for row in stride(from: Self.rows - 1, through: 0, by: -1) {
            if grid[row][col] == 0 {
                grid[row][col] = turn
                dropColumn = col
                dropRow = row
                dropTick += 1
                if checkWin(player: turn, row: row, col: col) {
                    winner = turn
                } else {
                    turn = turn == 1 ? 2 : 1
                }
                return true
            }
        }
        return false
    }

    private func checkWin(player: Int, row: Int, col: Int) -> Bool {
        let dirs = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for (dr, dc) in dirs {
            var line: [(Int, Int)] = [(row, col)]
            for sign in [1, -1] {
                var r = row + dr * sign
                var c = col + dc * sign
                while r >= 0, r < Self.rows, c >= 0, c < Self.cols, grid[r][c] == player {
                    line.append((r, c))
                    r += dr * sign
                    c += dc * sign
                }
            }
            if line.count >= 4 {
                winningCells = line
                return true
            }
        }
        return false
    }
}

struct Connect4View: View {
    let players: [GamePlayer]
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = Connect4Engine()
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var confettiTick = 0
    @State private var boardEntrance = false
    @State private var boardShake = 0

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#D97868")
    }
    private var p2: GamePlayer {
        players.count > 1 ? players[1] : GamePlayer(displayName: "Player 2", colorHex: "#D59A3A")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                ArcadeGameHeader(title: "Connect 4", emoji: "🔴", onExit: onExit)
                MultiplayerHUD(
                    players: [p1, p2],
                    activeIndex: engine.turn == 1 ? 0 : 1,
                    turnLabel: engine.winner == nil
                        ? "\(engine.turn == 1 ? p1.displayName : p2.displayName)'s turn"
                        : nil
                )
                boardView
                Spacer(minLength: 8)
                SecondaryButton(title: "New game") {
                    GameSounds.restart()
                    engine.reset()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if matchOver {
                GameResultView(
                    title: "🎉 You Win!",
                    message: engine.winner == 1 ? p1.displayName : p2.displayName,
                    players: resultPlayers(),
                    winnerIds: [engine.winner == 1 ? p1.id : p2.id],
                    onRematch: {
                        matchOver = false
                        engine.reset()
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            startedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
        }
        .onChange(of: engine.winner) { _, w in
            guard w != nil else { return }
            confettiTick += 1
            GameSounds.win()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { record() }
        }
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = engine.winner == 1 ? 1 : 0
        var b = p2
        b.score = engine.winner == 2 ? 1 : 0
        return [a, b]
    }

    private func record() {
        GameStatsStore.shared.record(
            gameId: .connect4,
            players: resultPlayers(),
            winnerIds: [engine.winner == 1 ? p1.id : p2.id],
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private var boardView: some View {
        GeometryReader { geo in
            let cols = CGFloat(Connect4Engine.cols)
            let rows = CGFloat(Connect4Engine.rows)
            let cell = min(geo.size.width / cols, geo.size.height / rows)
            let w = cell * cols
            let h = cell * rows

            VStack(spacing: 6) {
                // Column tap targets (preview)
                HStack(spacing: 0) {
                    ForEach(0..<Connect4Engine.cols, id: \.self) { c in
                        Button {
                            guard engine.winner == nil else { return }
                            GameSounds.place()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                engine.drop(col: c)
                            }
                            if !reduceMotion {
                                boardShake += 1
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: engine.turn == 1 ? p1.colorHex : p2.colorHex).opacity(0.2))
                                .frame(width: cell * 0.55, height: cell * 0.55)
                                .padding(.vertical, 4)
                                .frame(width: cell)
                        }
                        .buttonStyle(GameCellPressStyle())
                        .disabled(engine.winner != nil)
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#285B82"))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    VStack(spacing: 4) {
                        ForEach(0..<Connect4Engine.rows, id: \.self) { r in
                            HStack(spacing: 4) {
                                ForEach(0..<Connect4Engine.cols, id: \.self) { c in
                                    piece(r: r, c: c, cell: cell * 0.88)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(width: w, height: h)
                .offset(y: boardShake > 0 && !reduceMotion ? 2 : 0)
                .animation(.spring(response: 0.12, dampingFraction: 0.4), value: boardShake)
                .scaleEffect(boardEntrance ? 1 : 0.9)
                .opacity(boardEntrance ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
    }

    private func piece(r: Int, c: Int, cell: CGFloat) -> some View {
        let value = engine.grid[r][c]
        let isWin = engine.winningCells.contains { $0.0 == r && $0.1 == c }
        let color = value == 1 ? Color(hex: p1.colorHex) : value == 2 ? Color(hex: p2.colorHex) : Color.white.opacity(0.15)
        let isDropping = engine.dropRow == r && engine.dropColumn == c
        return Circle()
            .fill(value == 0 ? Color.white.opacity(0.92) : color)
            .frame(width: cell, height: cell)
            .scaleEffect(isWin && !reduceMotion ? 1.12 : 1)
            .scaleEffect(isDropping && !reduceMotion ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isWin)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: engine.dropTick)
    }
}
