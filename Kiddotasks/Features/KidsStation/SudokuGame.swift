import SwiftUI

// MARK: - Engine

@MainActor
@Observable
final class SudokuEngine {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        var id: String { rawValue }
        var removeCount: Int {
            switch self {
            case .easy: return 36
            case .medium: return 46
            case .hard: return 54
            }
        }
        var emoji: String {
            switch self {
            case .easy: return "🟢"
            case .medium: return "🟡"
            case .hard: return "🔴"
            }
        }
    }

    static let size = 9
    static let maxMistakes = 5

    var solution: [[Int]] = []
    var puzzle: [[Int]] = []
    var grid: [[Int]] = []
    var givens: Set<Int> = []
    var selected: (Int, Int)?
    var mistakeCount = 0
    var isComplete = false
    var progress: Double = 0
    var filledCount = 0
    var editableCount = 0
    var lastPlaced: (Int, Int)?
    var placeTick = 0
    var wrongCell: (Int, Int)?
    var shakeTick = 0
    var boardPulse = false
    var difficulty: Difficulty = .easy
    var elapsedSeconds = 0
    var timerRunning = false

    private var timerTask: Task<Void, Never>?

    func start(difficulty: Difficulty = .easy) {
        self.difficulty = difficulty
        solution = Self.generateSolvedBoard()
        puzzle = solution
        grid = solution
        let total = Self.size * Self.size
        var blanks = Array(0..<total).shuffled()
        var removed = 0
        for idx in blanks {
            if removed >= difficulty.removeCount { break }
            grid[idx / Self.size][idx % Self.size] = 0
            removed += 1
        }
        // Keep puzzle as the carved board (immutable givens).
        puzzle = grid
        givens = Set(
            (0..<total).filter { grid[$0 / Self.size][$0 % Self.size] != 0 }
        )
        editableCount = total - givens.count
        selected = nil
        mistakeCount = 0
        isComplete = false
        lastPlaced = nil
        wrongCell = nil
        boardPulse = false
        elapsedSeconds = 0
        timerRunning = true
        recalcProgress()
        startTimer()
        blanks = []
    }

    func stopTimer() {
        timerRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self, self.timerRunning, !self.isComplete {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if self.timerRunning, !self.isComplete {
                    self.elapsedSeconds += 1
                }
            }
        }
    }

    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func select(r: Int, c: Int) {
        guard !isComplete else { return }
        selected = (r, c)
        wrongCell = nil
    }

    func place(_ n: Int) {
        guard !isComplete, let (r, c) = selected, !givens.contains(r * Self.size + c) else { return }
        if solution[r][c] == n {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.52)) {
                grid[r][c] = n
                lastPlaced = (r, c)
                placeTick += 1
            }
            wrongCell = nil
            GameSounds.match()
            Haptic.light()
            recalcProgress()
            if isBoardFullAndCorrect() {
                isComplete = true
                stopTimer()
                boardPulse = true
                GameSounds.win()
                Haptic.success()
            }
        } else {
            mistakeCount += 1
            wrongCell = (r, c)
            shakeTick += 1
            GameSounds.miss()
            Haptic.warning()
        }
    }

    func erase() {
        guard !isComplete, let (r, c) = selected, !givens.contains(r * Self.size + c) else { return }
        grid[r][c] = 0
        wrongCell = nil
        recalcProgress()
    }

    // MARK: Highlights

    func isSameRowColBox(_ r: Int, _ c: Int) -> Bool {
        guard let (sr, sc) = selected else { return false }
        if r == sr || c == sc { return true }
        return (r / 3) == (sr / 3) && (c / 3) == (sc / 3)
    }

    func isSameNumber(_ r: Int, _ c: Int) -> Bool {
        guard let (sr, sc) = selected else { return false }
        let selectedVal = grid[sr][sc]
        guard selectedVal != 0 else { return false }
        return grid[r][c] == selectedVal
    }

    private func recalcProgress() {
        let total = Self.size * Self.size
        filledCount = grid.flatMap { $0 }.filter { $0 != 0 }.count
        progress = Double(filledCount) / Double(total)
    }

    private func isBoardFullAndCorrect() -> Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size where grid[r][c] != solution[r][c] {
                return false
            }
        }
        return true
    }

    // MARK: Generation

    static func generateSolvedBoard() -> [[Int]] {
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
    @State private var showHelp = false
    @State private var showIntro = true

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#285B82")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ArcadeGameHeader(title: "Sudoku", emoji: "🧩", onExit: onExit)
                statsBar
                boardView
                padView
                controlsRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick)
                .ignoresSafeArea()

            if showIntro {
                introOverlay
            }

            if showHelp {
                helpOverlay
            }

            if matchOver {
                GameResultView(
                    title: "🎉 Sudoku Complete!",
                    message: "Amazing job!\nTime \(engine.formattedTime) · Mistakes \(engine.mistakeCount)",
                    players: resultPlayers(),
                    winnerIds: [p1.id],
                    onRematch: {
                        matchOver = false
                        newGame()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showIntro)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: showHelp)
        .onAppear {
            startedAt = Date()
        }
        .onDisappear { engine.stopTimer() }
        .onChange(of: engine.shakeTick) { _, _ in
            guard engine.wrongCell != nil, !reduceMotion else { return }
            shakeAngle = -3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { shakeAngle = 3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { shakeAngle = -2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { shakeAngle = 0 }
        }
        .onChange(of: engine.isComplete) { _, done in
            guard done else { return }
            confettiTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { record() }
        }
    }

    // MARK: Intro

    private var introOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("🧩")
                    .font(.system(size: 56))
                Text("Sudoku")
                    .font(KiddoTasksDesignTokens.Typography.displaySmall)
                Text("Ready to solve?")
                    .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                difficultyPicker
                PrimaryButton(title: "Play") {
                    newGame()
                    showIntro = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        boardEntrance = true
                    }
                }
                SecondaryButton(title: "How to play") { showHelp = true }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
            )
            .scaleEffect(showIntro ? 1 : 0.9)
        }
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(SudokuEngine.Difficulty.allCases) { d in
                Button {
                    engine.difficulty = d
                    Haptic.light()
                } label: {
                    Text("\(d.emoji) \(d.rawValue)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                engine.difficulty == d
                                    ? KiddoTasksDesignTokens.Colors.primary
                                    : KiddoTasksDesignTokens.Colors.surface
                            )
                        )
                        .foregroundStyle(engine.difficulty == d ? .white : KiddoTasksDesignTokens.Colors.text)
                }
                .buttonStyle(GameCellPressStyle())
            }
        }
    }

    // MARK: Stats

    private var statsBar: some View {
        HStack(spacing: 10) {
            Label(engine.formattedTime, systemImage: "timer")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .monospacedDigit()
            Spacer()
            Text("❤️ \(max(0, SudokuEngine.maxMistakes - engine.mistakeCount))")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(
                    engine.mistakeCount >= SudokuEngine.maxMistakes - 1
                        ? KiddoTasksDesignTokens.Colors.error
                        : KiddoTasksDesignTokens.Colors.text
                )
            Text("\(engine.filledCount)/81")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.bold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                .monospacedDigit()
                .scaleEffect(engine.placeTick > 0 && !reduceMotion ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: engine.placeTick)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Board — cells ARE interactive (grid lines are hit-test disabled)

    private var boardView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                // Box tints (under cells)
                ForEach(0..<9, id: \.self) { box in
                    let br = (box / 3) * 3
                    let bc = (box % 3) * 3
                    let selectedBox = engine.selected.map { ($0.0 / 3) * 3 + ($0.1 / 3) } ?? -1
                    Rectangle()
                        .fill(
                            box == selectedBox
                                ? KiddoTasksDesignTokens.Colors.primaryLight.opacity(0.55)
                                : (box % 2 == 0
                                    ? Color.white.opacity(0.5)
                                    : KiddoTasksDesignTokens.Colors.surface.opacity(0.5))
                        )
                        .frame(width: cell * 3, height: cell * 3)
                        .position(
                            x: CGFloat(bc) * cell + cell * 1.5,
                            y: CGFloat(br) * cell + cell * 1.5
                        )
                }

                ForEach(0..<9, id: \.self) { r in
                    ForEach(0..<9, id: \.self) { c in
                        cellView(r: r, c: c, cell: cell)
                            .position(
                                x: CGFloat(c) * cell + cell / 2,
                                y: CGFloat(r) * cell + cell / 2
                            )
                            .scaleEffect(boardEntrance ? 1 : 0.6)
                            .opacity(boardEntrance ? 1 : 0)
                            .animation(
                                reduceMotion
                                    ? .default
                                    : .spring(response: 0.35, dampingFraction: 0.7)
                                        .delay(Double((r + c) % 9) * 0.02),
                                value: boardEntrance
                            )
                    }
                }

                // Grid lines — NEVER capture taps
                SudokuGridLines()
                    .allowsHitTesting(false)
                    .frame(width: side, height: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            )
            .scaleEffect(engine.boardPulse && !reduceMotion ? 1.02 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: engine.boardPulse)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private func cellView(r: Int, c: Int, cell: CGFloat) -> some View {
        let value = engine.grid.indices.contains(r) && engine.grid[r].indices.contains(c)
            ? engine.grid[r][c] : 0
        let key = r * 9 + c
        let isGiven = engine.givens.contains(key)
        let isSelected = engine.selected?.0 == r && engine.selected?.1 == c
        let isLast = engine.lastPlaced?.0 == r && engine.lastPlaced?.1 == c
        let isWrong = engine.wrongCell?.0 == r && engine.wrongCell?.1 == c
        let related = !isSelected && engine.isSameRowColBox(r, c)
        let sameNum = !isSelected && engine.isSameNumber(r, c)

        return Button {
            engine.select(r: r, c: c)
            GameSounds.tap()
            Haptic.light()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(cellBackground(
                        isSelected: isSelected,
                        related: related,
                        sameNum: sameNum,
                        isLast: isLast
                    ))
                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: max(12, cell * 0.46), weight: isGiven ? .heavy : .bold, design: .rounded))
                        .foregroundStyle(
                            isWrong
                                ? KiddoTasksDesignTokens.Colors.error
                                : (isGiven
                                    ? KiddoTasksDesignTokens.Colors.text
                                    : KiddoTasksDesignTokens.Colors.primary)
                        )
                        .id("\(r)-\(c)-\(value)-\(engine.placeTick)")
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? KiddoTasksDesignTokens.Colors.primary
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1)
            .rotationEffect(.degrees(isWrong && !reduceMotion ? shakeAngle : 0))
            .animation(.easeOut(duration: 0.14), value: isSelected)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: isLast)
            .animation(.easeOut(duration: 0.12), value: isWrong)
        }
        .buttonStyle(GameCellPressStyle())
        .accessibilityLabel(accessibilityLabel(r: r, c: c, value: value, isGiven: isGiven))
    }

    @State private var shakeAngle: Double = 0

    private func cellBackground(
        isSelected: Bool,
        related: Bool,
        sameNum: Bool,
        isLast: Bool
    ) -> Color {
        if isSelected { return KiddoTasksDesignTokens.Colors.primaryLight }
        if sameNum { return KiddoTasksDesignTokens.Colors.rewardLight }
        if related { return KiddoTasksDesignTokens.Colors.surface }
        if isLast && !reduceMotion { return KiddoTasksDesignTokens.Colors.successLight.opacity(0.7) }
        return .clear
    }

    private func accessibilityLabel(r: Int, c: Int, value: Int, isGiven: Bool) -> String {
        let pos = "row \(r + 1) column \(c + 1)"
        if value == 0 { return "Empty, \(pos)" }
        return "\(value), \(pos)\(isGiven ? ", given" : "")"
    }

    // MARK: Pad

    private var padView: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { col in
                        let n = row * 3 + col
                        numberButton(n)
                    }
                }
            }
            HStack(spacing: 6) {
                Button {
                    engine.erase()
                    GameSounds.tap()
                } label: {
                    Text("⌫")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.attentionLight)
                        )
                }
                .buttonStyle(GameCellPressStyle())
                .disabled(engine.isComplete || engine.selected == nil)

                Spacer(minLength: 0)

                Button {
                    showHelp = true
                } label: {
                    Text("❓ Help")
                        .font(.caption.weight(.bold))
                        .frame(height: 48)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.surface)
                        )
                }
                .buttonStyle(GameCellPressStyle())
            }
        }
        .padding(.horizontal, 12)
    }

    private func numberButton(_ n: Int) -> some View {
        Button {
            engine.place(n)
        } label: {
            Text("\(n)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
        }
        .buttonStyle(GameCellPressStyle())
        .disabled(engine.isComplete || engine.selected == nil)
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            SecondaryButton(title: "🔄 New game") {
                newGame()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: Help modal

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showHelp = false }
            VStack(spacing: 12) {
                HStack {
                    Text("🧩 How to Play Sudoku")
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        showHelp = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(GameCellPressStyle())
                    .accessibilityLabel("Close")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Goal")
                            .font(.headline)
                        Text("Fill the board with numbers 1–9.")
                            .font(.caption)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        Text("Rule 1 — Rows")
                            .font(.subheadline.bold())
                        Text("Each row needs 1–9 with no repeats.")
                            .font(.caption)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        Text("Rule 2 — Columns")
                            .font(.subheadline.bold())
                        Text("Each column needs 1–9 with no repeats.")
                            .font(.caption)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        Text("Rule 3 — Boxes")
                            .font(.subheadline.bold())
                        Text("Each 3×3 box needs 1–9 with no repeats.")
                            .font(.caption)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        Text("How to play")
                            .font(.subheadline.bold())
                        Text("1. Tap an empty square\n2. Pick a number\n3. Keep going until the board is full!")
                            .font(.caption)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                PrimaryButton(title: "Got it!") { showHelp = false }
            }
            .padding(20)
            .frame(maxWidth: 340, maxHeight: 480)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
            )
            .scaleEffect(showHelp ? 1 : 0.85)
            .opacity(showHelp ? 1 : 0)
        }
        .allowsHitTesting(showHelp)
    }

    // MARK: Actions

    private func newGame() {
        GameSounds.restart()
        withAnimation(.easeIn(duration: 0.15)) { boardEntrance = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            engine.start(difficulty: engine.difficulty)
            startedAt = Date()
            matchOver = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
        }
    }

    private func resultPlayers() -> [GamePlayer] {
        var a = p1
        a.score = 50 // simple star reward
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
}

// MARK: - Grid lines (non-interactive)

private struct SudokuGridLines: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let thin = Color(hex: "#D9E1E8")
            let thick = KiddoTasksDesignTokens.Colors.textSecondary

            // Fine lines
            for i in 1..<9 {
                if i % 3 != 0 {
                    let x = w * CGFloat(i) / 9
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    context.stroke(path, with: .color(thin), lineWidth: 0.5)

                    let y = h * CGFloat(i) / 9
                    var path2 = Path()
                    path2.move(to: CGPoint(x: 0, y: y))
                    path2.addLine(to: CGPoint(x: w, y: y))
                    context.stroke(path2, with: .color(thin), lineWidth: 0.5)
                }
            }

            // 3×3 heavy lines
            for i in 1...2 {
                let x = w * CGFloat(i) / 3
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: h))
                context.stroke(path, with: .color(thick), lineWidth: 2)

                let y = h * CGFloat(i) / 3
                var path2 = Path()
                path2.move(to: CGPoint(x: 0, y: y))
                path2.addLine(to: CGPoint(x: w, y: y))
                context.stroke(path2, with: .color(thick), lineWidth: 2)
            }

            // Outer border
            context.stroke(
                Path(CGRect(x: 1, y: 1, width: w - 2, height: h - 2)),
                with: .color(thick),
                lineWidth: 2
            )
        }
    }
}
