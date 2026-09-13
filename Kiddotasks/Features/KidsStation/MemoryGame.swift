import SwiftUI

/// Board difficulty. Odd sizes use n×(n−1) cards so every tile has a pair.
enum MemoryBoardSize: Int, CaseIterable, Identifiable {
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8

    var id: Int { rawValue }

    var label: String { "\(rawValue)×\(rawValue)" }

    /// Even card count (pairs × 2).
    var cardCount: Int {
        rawValue * (rawValue % 2 == 0 ? rawValue : rawValue - 1)
    }

    var pairCount: Int { cardCount / 2 }

    /// Preferred column count for LazyVGrid.
    var columns: Int { rawValue }

    var detail: String {
        "\(pairCount) pairs · \(cardCount) tiles"
    }
}

@MainActor
@Observable
final class MemoryGameEngine {
    struct Card: Identifiable, Equatable {
        let id: Int
        let pairId: Int
        let glyph: String
        var isFaceUp = false
        var isMatched = false
    }

    /// Enough faces for an 8×8 board (32 pairs).
    private static let glyphPool: [String] = [
        "🐶", "🐱", "🦊", "🐼", "🦁", "🐸", "🦄", "🐙",
        "🦋", "🌈", "⭐", "🚀", "🍎", "🍕", "⚽️", "🎯",
        "🎵", "🎨", "🦕", "🐳", "🐝", "🐞", "🌵", "🌙",
        "☀️", "❄️", "🍩", "🍪", "🧁", "🎈", "🎁", "🏆",
    ]

    var cards: [Card] = []
    var flippedIndices: [Int] = []
    var scores: [String: Int] = [:]
    var currentPlayerIndex = 0
    var playerNames: [String] = []
    var isBusy = false
    var boardSize: MemoryBoardSize = .four
    /// Incremented after every flip resolution so views can detect board completion.
    var flipGeneration = 0
    /// Last resolved pair outcome for FX (true = match).
    var lastWasMatch = false
    var lastFlippedPair: [Int] = []

    var isComplete: Bool { !cards.isEmpty && cards.allSatisfy(\.isMatched) }

    func start(playerNames: [String], boardSize: MemoryBoardSize = .four) {
        self.playerNames = playerNames.isEmpty ? ["Player"] : playerNames
        self.boardSize = boardSize
        scores = Dictionary(uniqueKeysWithValues: self.playerNames.map { ($0, 0) })
        currentPlayerIndex = 0

        let pairTotal = boardSize.pairCount
        let glyphs = Array(Self.glyphPool.shuffled().prefix(pairTotal))
        var deck: [Card] = []
        var id = 0
        for (pairIndex, glyph) in glyphs.enumerated() {
            deck.append(Card(id: id, pairId: pairIndex, glyph: glyph))
            id += 1
            deck.append(Card(id: id, pairId: pairIndex, glyph: glyph))
            id += 1
        }
        cards = deck.shuffled()
        flippedIndices = []
        flipGeneration = 0
        lastWasMatch = false
        lastFlippedPair = []
    }

    func flip(at index: Int) -> Bool {
        guard !isBusy, index >= 0, index < cards.count,
              !cards[index].isFaceUp, !cards[index].isMatched, flippedIndices.count < 2 else { return false }
        cards[index].isFaceUp = true
        flippedIndices.append(index)
        GameSounds.flip()
        Haptic.light()

        guard flippedIndices.count == 2 else { return true }
        isBusy = true
        let first = flippedIndices[0]
        let second = flippedIndices[1]
        let name = playerNames.indices.contains(currentPlayerIndex) ? playerNames[currentPlayerIndex] : "Player"
        Task { @MainActor in
            // Give the second card time to finish its flip.
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard first < cards.count, second < cards.count else {
                flippedIndices = []
                isBusy = false
                return
            }
            lastFlippedPair = [first, second]
            if cards[first].pairId == cards[second].pairId {
                lastWasMatch = true
                cards[first].isMatched = true
                cards[second].isMatched = true
                scores[name, default: 0] += 1
                GameSounds.match()
                Haptic.success()
            } else {
                lastWasMatch = false
                // Hold face-up a beat so kids can recognize, then flip back.
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard first < cards.count, second < cards.count else {
                    flippedIndices = []
                    isBusy = false
                    return
                }
                cards[first].isFaceUp = false
                cards[second].isFaceUp = false
                currentPlayerIndex = (currentPlayerIndex + 1) % max(playerNames.count, 1)
                GameSounds.miss()
                Haptic.light()
            }
            flippedIndices = []
            isBusy = false
            flipGeneration += 1
        }
        return true
    }
}

struct MemoryGameView: View {
    let players: [GamePlayer]
    var boardSize: MemoryBoardSize = .four
    var requirePassDevice = false
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var engine = MemoryGameEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()

    // FX
    @State private var boardEntrance = false
    @State private var matchSparkle: Set<Int> = []
    @State private var shakeIndices: Set<Int> = []
    @State private var confettiTick = 0
    @State private var scorePopTick = 0
    @State private var toast: String?
    @State private var toastTick = 0

    private var names: [String] { players.map(\.displayName) }
    private var totalPairs: Int { boardSize.pairCount }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                header
                progressStars
                boardView
                Spacer(minLength: 8)
                SecondaryButton(title: "End game") { finish() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            ConfettiOverlay(trigger: confettiTick, particleCount: 52)
                .ignoresSafeArea()

            if let toast {
                Text(toast)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                    .scaleEffect(toastTick % 2 == 0 ? 0.85 : 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 100)
                    .allowsHitTesting(false)
            }

            if matchOver {
                GameResultView(
                    title: "🎉 Amazing!",
                    message: "You found them all!\n" + scoresSummary(),
                    players: resultPlayers(),
                    winnerIds: winnerIds(),
                    onRematch: {
                        matchOver = false
                        resetFX()
                        engine.start(playerNames: names, boardSize: boardSize)
                        boardEntrance = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { boardEntrance = true }
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: matchOver)
        .onAppear {
            engine.start(playerNames: names, boardSize: boardSize)
            startedAt = Date()
            if reduceMotion {
                boardEntrance = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { boardEntrance = true }
            }
        }
        .onChange(of: engine.flipGeneration) { _, _ in
            handleFlipResolved()
        }
    }

    private func resetFX() {
        matchSparkle = []
        shakeIndices = []
        toast = nil
    }

    private func handleFlipResolved() {
        if engine.lastWasMatch {
            scorePopTick += 1
            showToast("✨ Match!")
            for i in engine.lastFlippedPair {
                matchSparkle.insert(i)
            }
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    for i in engine.lastFlippedPair { matchSparkle.remove(i) }
                }
            }
        } else {
            showToast("👀 Try again!")
            if !reduceMotion {
                shakeIndices = Set(engine.lastFlippedPair)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shakeIndices = []
                }
            }
        }

        if engine.isComplete, !matchOver {
            confettiTick += 1
            scorePopTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                finish()
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTick += 1
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            toastTick += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            if toast == text { toast = nil }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("🧠 Memory")
                .font(KiddoTasksDesignTokens.Typography.headingMedium)
            if !engine.playerNames.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(KiddoTasksDesignTokens.Colors.primary)
                        .frame(width: 10, height: 10)
                    Text("\(engine.playerNames[engine.currentPlayerIndex])'s turn")
                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.currentPlayerIndex)
            }
            Text(engine.playerNames.map { "\($0): \(engine.scores[$0] ?? 0)" }.joined(separator: " · "))
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .scaleEffect(scorePopTick > 0 && !reduceMotion ? 1.1 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: scorePopTick)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }

    private var progressStars: some View {
        let total = totalPairs
        let found = engine.cards.filter(\.isMatched).count / 2
        // Compact indicator for large boards; star row for small ones.
        if total <= 12 {
            return AnyView(
                HStack(spacing: 4) {
                    ForEach(0..<total, id: \.self) { i in
                        Text(i < found ? "⭐" : "☆")
                            .font(.system(size: total > 8 ? 12 : 14))
                            .opacity(i < found ? 1 : 0.3)
                            .scaleEffect(i == found - 1 && !reduceMotion ? 1.25 : 1)
                            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: found)
                    }
                }
                .accessibilityLabel("\(found) of \(total) pairs found")
            )
        }
        return AnyView(
            Text("\(found) / \(total) pairs")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .fontWeight(.semibold)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.9)))
                .scaleEffect(scorePopTick > 0 && !reduceMotion ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: scorePopTick)
                .accessibilityLabel("\(found) of \(total) pairs found")
        )
    }

    private var boardView: some View {
        GeometryReader { geo in
            let spacing: CGFloat = boardSize.rawValue >= 7 ? 6 : 10
            let preferred = boardSize.columns
            let cols = max(3, min(preferred, Int(geo.size.width / 56)))
            let cardW = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cardH = max(cardW * 1.12, 48)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cardW), spacing: spacing), count: cols),
                spacing: spacing
            ) {
                ForEach(Array(engine.cards.enumerated()), id: \.element.id) { index, card in
                    MemoryCardView(
                        card: card,
                        width: cardW,
                        height: cardH,
                        isShaking: shakeIndices.contains(index) && !reduceMotion,
                        isSparkling: matchSparkle.contains(index) && !reduceMotion,
                        reduceMotion: reduceMotion,
                        onFlip: {
                            _ = engine.flip(at: index)
                        }
                    )
                    .scaleEffect(boardEntrance ? 1 : 0.55)
                    .opacity(boardEntrance ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? .default
                            : .spring(response: 0.4, dampingFraction: 0.65)
                                .delay(Double(index % max(cols, 1)) * 0.02),
                        value: boardEntrance
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: boardSize.rawValue >= 6 ? 560 : 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, boardSize.rawValue >= 6 ? 10 : 16)
    }

    private func resultPlayers() -> [GamePlayer] {
        players.map { p in
            var copy = p
            copy.score = engine.scores[p.displayName] ?? 0
            return copy
        }
    }

    private func winnerIds() -> [String] {
        let scored = players.map { ($0, engine.scores[$0.displayName] ?? 0) }
        guard let max = scored.map({ $0.1 }).max(), max > 0 else { return [] }
        return scored.filter { $0.1 == max }.map { $0.0.id }
    }

    private func scoresSummary() -> String {
        names.map { "\($0) \(engine.scores[$0] ?? 0)" }.joined(separator: " · ")
    }

    private func finish() {
        GameStatsStore.shared.record(
            gameId: .memory,
            players: resultPlayers(),
            winnerIds: winnerIds(),
            durationSeconds: Int(Date().timeIntervalSince(startedAt)),
            notifyParents: appState.currentFamily?.settings.enableNotifications ?? true
        )
        matchOver = true
    }
}

// MARK: - 3D flip card

private struct MemoryCardView: View {
    let card: MemoryGameEngine.Card
    let width: CGFloat
    let height: CGFloat
    let isShaking: Bool
    let isSparkling: Bool
    let reduceMotion: Bool
    let onFlip: () -> Void

    @State private var shakeX: CGFloat = 0

    private var isRevealed: Bool { card.isFaceUp || card.isMatched }

    var body: some View {
        Button(action: onFlip) {
            ZStack {
                // Back
                cardFace(isFront: false)
                    .opacity(isRevealed ? 0 : 1)

                // Front
                cardFace(isFront: true)
                    .opacity(isRevealed ? 1 : 0)
                    .scaleEffect(isRevealed ? 1 : 0.85)
            }
            .frame(width: width, height: height)
            .rotation3DEffect(
                .degrees(isRevealed ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.65
            )
            .scaleEffect(isSparkling ? 1.06 : 1)
            .offset(x: shakeX)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isRevealed)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isSparkling)
            .contentShape(Rectangle())
        }
        .buttonStyle(GameCellPressStyle())
        .disabled(card.isMatched)
        .onChange(of: isShaking) { _, shaking in
            guard shaking else {
                shakeX = 0
                return
            }
            shakeX = -4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { shakeX = 4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { shakeX = -3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { shakeX = 0 }
        }
        .overlay {
            if isSparkling {
                SparkleBurst(active: true, color: Color(hex: "#D59A3A"))
            }
        }
        .accessibilityLabel(isRevealed ? card.glyph : "Hidden card")
        .accessibilityHint("Flip card")
    }

    private func cardFace(isFront: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                isFront
                    ? (card.isMatched
                        ? KiddoTasksDesignTokens.Colors.successLight
                        : KiddoTasksDesignTokens.Colors.surfaceCard)
                    : Color(hex: "#285B82")
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isFront
                            ? (card.isMatched
                                ? KiddoTasksDesignTokens.Colors.success.opacity(0.5)
                                : KiddoTasksDesignTokens.Colors.primary.opacity(0.3))
                            : Color.white.opacity(0.15),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
            .overlay {
                if isFront {
                    Text(card.glyph)
                        .font(.system(size: max(28, width * 0.42)))
                        .scaleEffect(isRevealed && !reduceMotion ? 1 : 0.8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isRevealed)
                } else {
                    Text("🎮")
                        .font(.system(size: max(22, width * 0.32)))
                        .opacity(0.9)
                }
            }
            .opacity(card.isMatched && isFront ? 0.78 : 1)
    }
}
