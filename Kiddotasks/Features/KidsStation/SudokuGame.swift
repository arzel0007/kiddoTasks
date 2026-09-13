import SwiftUI

// MARK: - Engine

@MainActor
@Observable
final class SudokuEngine {
    static let size = 9

    /// Solution grid (0-based [row][col]).
    var solution: [[Int]] = []
    /// Current player grid (0 = empty).
    var grid: [[Int]] = []
    /// Given cells that cannot be edited.
    var givens: Set<Int> = [] // r * 9 + c
    var selected: (Int, Int)?
    var mistakeCount = 0
    var isComplete = false
    var progress: Double = 0
    var lastPlaced: (Int, Int)?
    var placeTick = 0
    var shakeTick = 0

    func start(removeCount: Int = 40) {
        solution = Self.generate()
        grid = solution
        var blanks: [Int] = Array(0..<(Self.size * Self.size)).shuffled()
        givens = []
        var removed = 0
        for idx in blanks {
            if removed >= removeCount { break }
            let r = idx / Self.size
            let c = idx % Self.size
            grid[r][c] = 0
            removed += 1
        }
        givens = Set(
            (0..<(Self.size * Self.size)).filter { idx in
                let r = idx / Self.size
                let c = idx % Self.size
                return grid[r][c] != 0
            }
        )
        selected = nil
        mistakeCount = 0
        isComplete = false
        lastPlaced = nil
        recalcProgress()
    }

    func select(r: Int, c: Int) {
        guard !isComplete else { return }
        selected = (r, c)
    }

    func place(_ n: Int) {
        guard !isComplete, let (r, c) = selected, !givens.contains(r * Self.size + c) else { return }
        if solution[r][c] == n {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                grid[r][c] = n
                lastPlaced = (r, c)
                placeTick += 1
            }
            GameSounds.match()
            Haptic.light()
            recalcProgress()
            if isBoardFullAndCorrect() {
                isComplete = true
                GameSounds.win()
                Haptic.success()
            }
        } else {
            mistakeCount += 1
            shakeTick += 1
            GameSounds.miss()
            Haptic.warning()
        }
    }

    func erase() {
        guard !isComplete, let (r, c) = selected, !givens.contains(r * Self.size + c) else { return }
        grid[r][c] = 0
        recalcProgress()
    }

    private func recalcProgress() {
        let total = Self.size * Self.size
        let filled = grid.flatMap { $0 }.filter { $0 != 0 }.count
        progress = Double(filled) / Double(total)
    }

    private func isBoardFullAndCorrect() -> Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size where grid[r][c] != solution[r][c] {
                return false
            }
        }
        return true
    }

    // Simple valid grid generator (filled then carved)
    private static func generate() -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = fill(&g, row: 0, col: 0)
        return g
    }

    private static func fill(_ g: inout [[Int]], row: Int, col: Int) -> Bool {
        if row == 9 { return true }
        let nextRow = col == 8 ? row + 1 : row
        let nextCol = col == 8 ? 0 : col + 1
        var nums = Array(1...9).shuffled()
        for n in nums {
            if isValid(g, row, col, n) {
                g[row][col] = n
                if fill(&g, row: nextRow, col: nextCol) { return true }
                g[row][col] = 0
            }
        }
        nums = []
        return false
    }

    private static func isValid(_ g: [[Int]], _ r: Int, _ c: Int, _ n: Int) -> Bool {
        for i in 0..<9 where g[r][i] == n || g[i][c] == n { return false }
        let br = (r / 3) * 3
        let bc = (c / 3) * 3
        for i in br..<(br + 3) {
            for j in bc..<(bc + 3) where g[i][j] == n { return false }
        }
        return true
    }
}

// MARK: - View

struct SudokuView: View {
    let players: [GamePlayer]
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = SudokuEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var confettiTick = 0
    @State private var boardEntrance = false

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#285B82")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                ArcadeGameHeader(title: "Sudoku", emoji: "🔢", onExit: onExit)
                HStack {
                    Text("\(Int(engine.progress * 100))% filled")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    Spacer()
                    Text("Mistakes: \(engine.mistakeCount)")
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
                .padding(.horizontal, 16)

                ProgressView(value: engine.progress)
                    .tint(KiddoTasksDesignTokens.Colors.success)
                    .padding(.horizontal, 16)

                boardView
                padView
                SecondaryButton(title: "New puzzle") {
                    GameSounds.restart()
                    engine.start()
                    startedAt = Date()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if matchOver {
                GameResultView(
                    title: "🎉 Solved!",
                    message: "Mistakes: \(engine.mistakeCount)",
                    players: resultPlayers(),
                    winnerIds: [p1.id],
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
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            engine.start()
            startedAt = Date()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
        }
        .onChange(of: engine.isComplete) { _, done in
            guard done else { return }
            confettiTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { record() }
        }
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = max(0, 100 - engine.mistakeCount * 5)
        return [a]
    }

    private func record() {
        GameStatsStore.shared.record(
            gameId: .sudoku,
            players: resultPlayers(),
            winnerIds: [p1.id],
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }

    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9

            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { c in
                            cellView(r: r, c: c, cell: cell)
                        }
                    }
                }
            }
            .overlay(
                // 3x3 box lines
                GeometryReader { g in
                    Path { p in
                        let w = g.size.width
                        let h = g.size.height
                        for i in 1...2 {
                            let x = w * CGFloat(i) / 3
                            let y = h * CGFloat(i) / 3
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: h))
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                    }
                    .stroke(KiddoTasksDesignTokens.Colors.textSecondary, lineWidth: 2)
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            )
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(boardEntrance ? 1 : 0.95)
            .opacity(boardEntrance ? 1 : 0)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private func cellView(r: Int, c: Int, cell: CGFloat) -> some View {
        let value = engine.grid.indices.contains(r) && engine.grid[r].indices.contains(c)
            ? engine.grid[r][c] : 0
        let isGiven = engine.givens.contains(r * 9 + c)
        let isSelected = engine.selected?.0 == r && engine.selected?.1 == c
        let isLast = engine.lastPlaced?.0 == r && engine.lastPlaced?.1 == c

        return Button {
            engine.select(r: r, c: c)
            GameSounds.tap()
        } label: {
            Text(value == 0 ? "" : "\(value)")
                .font(.system(size: max(12, cell * 0.48), weight: isGiven ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(
                    isGiven
                        ? KiddoTasksDesignTokens.Colors.text
                        : KiddoTasksDesignTokens.Colors.primary
                )
                .frame(width: cell, height: cell)
                .background(
                    isSelected
                        ? KiddoTasksDesignTokens.Colors.primaryLight
                        : (isLast && !reduceMotion ? KiddoTasksDesignTokens.Colors.successLight : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .stroke(KiddoTasksDesignTokens.Colors.border.opacity(0.5), lineWidth: 0.5)
                )
                .scaleEffect(isLast && !reduceMotion ? 1.08 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isLast)
                .animation(.easeOut(duration: 0.12), value: isSelected)
        }
        .buttonStyle(GameCellPressStyle())
    }

    private var padView: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { n in
                Button {
                    engine.place(n)
                } label: {
                    Text("\(n)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                        )
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                }
                .buttonStyle(GameCellPressStyle())
                .disabled(engine.isComplete || engine.selected == nil)
            }
            Button {
                engine.erase()
            } label: {
                Text("⌫")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(KiddoTasksDesignTokens.Colors.attentionLight)
                    )
            }
            .buttonStyle(GameCellPressStyle())
        }
        .padding(.horizontal, 10)
    }
}
