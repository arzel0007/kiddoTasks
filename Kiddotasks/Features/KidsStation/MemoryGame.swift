import SwiftUI

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

    var cards: [Card] = []
    var flippedIndices: [Int] = []
    var scores: [String: Int] = [:]
    var currentPlayerIndex = 0
    var playerNames: [String] = []
    var isBusy = false

    func start(playerNames: [String]) {
        self.playerNames = playerNames
        scores = Dictionary(uniqueKeysWithValues: playerNames.map { ($0, 0) })
        currentPlayerIndex = 0
        let glyphs = ["🐶", "🐱", "🦊", "🐼", "🦁", "🐸", "🦄", "🐙", "🦋", "🌈", "⭐", "🚀"]
        let pairs = glyphs.prefix(8)
        var deck: [Card] = []
        var id = 0
        for pair in pairs {
            let pairId = id
            deck.append(Card(id: id, pairId: pairId, glyph: pair))
            id += 1
            deck.append(Card(id: id, pairId: pairId, glyph: pair))
            id += 1
        }
        cards = deck.shuffled()
        flippedIndices = []
    }

    func flip(at index: Int) {
        guard !isBusy, index >= 0, index < cards.count,
              !cards[index].isFaceUp, !cards[index].isMatched, flippedIndices.count < 2 else { return }
        cards[index].isFaceUp = true
        flippedIndices.append(index)
        Haptic.light()

        guard flippedIndices.count == 2 else { return }
        isBusy = true
        let first = flippedIndices[0]
        let second = flippedIndices[1]
        let name = playerNames.indices.contains(currentPlayerIndex) ? playerNames[currentPlayerIndex] : "Player"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard first < cards.count, second < cards.count else {
                flippedIndices = []
                isBusy = false
                return
            }
            if cards[first].pairId == cards[second].pairId {
                cards[first].isMatched = true
                cards[second].isMatched = true
                scores[name, default: 0] += 1
                Haptic.success()
            } else {
                cards[first].isFaceUp = false
                cards[second].isFaceUp = false
                currentPlayerIndex = (currentPlayerIndex + 1) % max(playerNames.count, 1)
                Haptic.light()
            }
            flippedIndices = []
            isBusy = false
            // Bump generation so the view can detect board completion after async match.
            flipGeneration += 1
        }
    }

    /// Incremented after every flip resolution so views can detect board completion.
    var flipGeneration = 0

    var isComplete: Bool { cards.allSatisfy(\.isMatched) }
}

struct MemoryGameView: View {
    let players: [GamePlayer]
    var requirePassDevice = false
    let onExit: () -> Void

    @Environment(AppState.self) private var appState
    @State private var engine = MemoryGameEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()

    private var names: [String] { players.map(\.displayName) }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                header
                boardView
                Spacer(minLength: 8)
                SecondaryButton(title: "End game") { finish() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())

            // Overlay (not fullScreenCover) — nested covers freeze inside Games hub.
            if matchOver {
                GameResultView(
                    title: "Nice memory!",
                    message: scoresSummary(),
                    players: resultPlayers(),
                    winnerIds: winnerIds(),
                    onRematch: {
                        matchOver = false
                        engine.start(playerNames: names)
                        startedAt = Date()
                    },
                    onExit: onExit
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: matchOver)
        .onAppear {
            engine.start(playerNames: names)
            startedAt = Date()
        }
        .onChange(of: engine.flipGeneration) { _, _ in
            // Match resolution is async — only finish once the board is actually complete.
            if engine.isComplete, !matchOver {
                finish()
            }
        }
    }

    private var boardView: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 10
            let cols = geo.size.width < 320 ? 3 : 4
            let cardW = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cardH = max(cardW * 1.15, 72)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cardW), spacing: spacing), count: cols),
                spacing: spacing
            ) {
                ForEach(Array(engine.cards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        engine.flip(at: index)
                    } label: {
                        Text(card.isFaceUp || card.isMatched ? card.glyph : "?")
                            .font(.system(size: max(28, cardW * 0.42)))
                            .frame(width: cardW, height: cardH)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(card.isMatched
                                        ? KiddoTasksDesignTokens.Colors.successLight
                                        : KiddoTasksDesignTokens.Colors.surfaceCard)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        card.isFaceUp && !card.isMatched
                                            ? KiddoTasksDesignTokens.Colors.primary.opacity(0.35)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(card.isFaceUp && !card.isMatched ? 1.02 : 1)
                            .opacity(card.isMatched ? 0.72 : 1)
                            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: card.isFaceUp)
                            .animation(.easeOut(duration: 0.2), value: card.isMatched)
                    }
                    .buttonStyle(KiddoPressStyle())
                    .disabled(engine.isBusy && !card.isFaceUp)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Memory")
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
            }
            Text(engine.playerNames.map { "\($0): \(engine.scores[$0] ?? 0)" }.joined(separator: " · "))
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
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
