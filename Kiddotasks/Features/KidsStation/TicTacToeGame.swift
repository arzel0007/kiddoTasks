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

    func resetBoard() {
        board = Array(repeating: Array(repeating: .empty, count: 3), count: 3)
        isXTurn = true
        outcome = .none
    }

    func tap(row: Int, col: Int) {
        guard outcome == .none, board[row][col] == .empty else { return }
        board[row][col] = isXTurn ? .x : .o
        evaluate()
        if outcome == .none {
            isXTurn.toggle()
        }
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
                xScore += 1
                Haptic.success()
                return
            }
            if vals[0] == .o && vals[1] == .o && vals[2] == .o {
                outcome = .oWins
                oScore += 1
                Haptic.success()
                return
            }
        }
        if board.flatMap({ $0 }).allSatisfy({ $0 != .empty }) {
            outcome = .draw
            Haptic.light()
        }
    }
}

struct TicTacToeView: View {
    let players: [GamePlayer]
    var requirePassDevice = true
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @State private var engine = TicTacToeEngine()
    @State private var showPass = false
    @State private var matchOver = false
    @State private var startedAt = Date()

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
                    PrimaryButton(title: "Next round") {
                        if engine.xScore + engine.oScore >= 3 {
                            finishMatch()
                        } else {
                            engine.resetBoard()
                        }
                    }
                    .padding(.horizontal, 20)
                }
                SecondaryButton(title: "End game") { finishMatch() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            if showPass {
                PassDeviceCard(playerName: passName(), colorHex: passColor()) {
                    showPass = false
                }
                .transition(.opacity)
            }

            // Overlay (not fullScreenCover) — nested covers inside the Games
            // hub cover freeze / fail to present on iOS.
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
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPass)
        .animation(.easeInOut(duration: 0.2), value: matchOver)
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
                Text("Tic-Tac-Toe")
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
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    /// Full-width square board sized from available space (not a tiny fixed grid).
    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 10
            let cell = (side - gap * 2) / 3

            VStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<3, id: \.self) { c in
                            Button {
                                engine.tap(row: r, col: c)
                                if requirePassDevice, engine.outcome == .none {
                                    showPass = true
                                }
                            } label: {
                                Text(mark(engine.board[r][c]))
                                    .font(.system(size: max(36, cell * 0.42), weight: .bold, design: .rounded))
                                    .frame(width: cell, height: cell)
                                    .background(
                                        RoundedRectangle(cornerRadius: max(14, cell * 0.16), style: .continuous)
                                            .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(14, cell * 0.16), style: .continuous)
                                            .strokeBorder(
                                                engine.board[r][c] == .empty
                                                    ? Color.clear
                                                    : (engine.board[r][c] == .x
                                                        ? Color(hex: p1.colorHex).opacity(0.35)
                                                        : Color(hex: p2.colorHex).opacity(0.35)),
                                                lineWidth: 2
                                            )
                                    )
                                    .foregroundStyle(engine.board[r][c] == .x
                                        ? Color(hex: p1.colorHex)
                                        : Color(hex: p2.colorHex))
                            }
                            .buttonStyle(KiddoPressStyle())
                            .disabled(engine.outcome != .none || engine.board[r][c] != .empty)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func mark(_ c: TicTacToeEngine.Cell) -> String {
        switch c {
        case .x: return "✕"
        case .o: return "○"
        case .empty: return ""
        }
    }

    private var statusLine: some View {
        VStack(spacing: 4) {
            Text(statusText)
                .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                .fontWeight(.semibold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            Text("\(p1.displayName) \(engine.xScore) · \(p2.displayName) \(engine.oScore)")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
    }

    private var statusText: String {
        switch engine.outcome {
        case .none: return "\(currentName)'s turn"
        case .xWins: return "\(p1.displayName) wins the round! 🎉"
        case .oWins: return "\(p2.displayName) wins the round! 🎉"
        case .draw: return "It's a draw!"
        }
    }
}
