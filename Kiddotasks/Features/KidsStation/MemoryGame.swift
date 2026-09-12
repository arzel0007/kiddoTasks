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
        guard !isBusy, !cards[index].isFaceUp, !cards[index].isMatched, flippedIndices.count < 2 else { return }
        cards[index].isFaceUp = true
        flippedIndices.append(index)
        Haptic.light()

        guard flippedIndices.count == 2 else { return }
        isBusy = true
        let first = flippedIndices[0]
        let second = flippedIndices[1]
        let name = playerNames[currentPlayerIndex]
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
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
        }
    }

    var isComplete: Bool { cards.allSatisfy(\.isMatched) }
}

struct MemoryGameView: View {
    let players: [GamePlayer]
    var requirePassDevice = false
    let onExit: () -> Void

    @State private var engine = MemoryGameEngine()
    @State private var matchOver = false
    @State private var startedAt = Date()

    private var names: [String] { players.map(\.displayName) }

    var body: some View {
        VStack(spacing: 12) {
            header
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                ForEach(Array(engine.cards.enumerated()), id: \.element.id) { index, card in
                    Button {
                        engine.flip(at: index)
                        if engine.isComplete { finish() }
                    } label: {
                        Text(card.isFaceUp || card.isMatched ? card.glyph : "?")
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(0.8, contentMode: .fit)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(card.isMatched
                                        ? KiddoTasksDesignTokens.Colors.successLight
                                        : KiddoTasksDesignTokens.Colors.surfaceCard)
                            )
                            .opacity(card.isMatched ? 0.7 : 1)
                    }
                    .buttonStyle(KiddoPressStyle())
                }
            }
            .padding(16)
            Spacer()
            SecondaryButton(title: "End game") { finish() }
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky.ignoresSafeArea())
        .onAppear {
            engine.start(playerNames: names)
            startedAt = Date()
        }
        .fullScreenCover(isPresented: $matchOver) {
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
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Memory")
                .font(KiddoTasksDesignTokens.Typography.headingMedium)
            if !engine.playerNames.isEmpty {
                Text("\(engine.playerNames[engine.currentPlayerIndex])'s turn")
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.primary)
            }
            Text(engine.playerNames.map { "\($0): \(engine.scores[$0] ?? 0)" }.joined(separator: " · "))
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
        }
        .padding(.top, 16)
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
            durationSeconds: Int(Date().timeIntervalSince(startedAt))
        )
        matchOver = true
    }
}
