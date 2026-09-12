import Foundation
import SwiftUI

// MARK: - Shared game identity

enum MiniGameID: String, CaseIterable, Identifiable {
    case basketball
    case tictactoe
    case memory
    case rps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basketball: return "Basketball"
        case .tictactoe: return "Tic-Tac-Toe"
        case .memory: return "Memory"
        case .rps: return "Rock Paper Scissors"
        }
    }

    var subtitle: String {
        switch self {
        case .basketball: return "1–2 players · timed shots"
        case .tictactoe: return "2 players · classic 3×3"
        case .memory: return "2–4 players · find pairs"
        case .rps: return "2 players · best of 3"
        }
    }

    var symbol: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .tictactoe: return "xmark.circle.fill"
        case .memory: return "rectangle.on.rectangle.fill"
        case .rps: return "hand.raised.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .basketball: return "#3978A8"
        case .tictactoe: return "#285B82"
        case .memory: return "#3F8B70"
        case .rps: return "#D59A3A"
        }
    }

    var minPlayers: Int {
        switch self {
        case .basketball: return 1
        default: return 2
        }
    }

    var maxPlayers: Int {
        switch self {
        case .basketball: return 2
        case .tictactoe: return 2
        case .rps: return 2
        case .memory: return 4
        }
    }
}

// MARK: - Players

struct GamePlayer: Identifiable, Equatable, Codable {
    let id: String
    var displayName: String
    var childId: String?
    var colorHex: String
    var score: Int
    var symbol: String

    init(
        id: String = UUID().uuidString,
        displayName: String,
        childId: String? = nil,
        colorHex: String = "#3978A8",
        score: Int = 0,
        symbol: String = "●"
    ) {
        self.id = id
        self.displayName = displayName
        self.childId = childId
        self.colorHex = colorHex
        self.score = score
        self.symbol = symbol
    }
}

// MARK: - Local stats (v1: UserDefaults)

struct GameMatchRecord: Codable, Identifiable, Equatable {
    let id: String
    let gameId: String
    /// Optional for older UserDefaults payloads; prefer `displayTitle`.
    let gameTitle: String?
    let playedAt: Date
    let players: [GamePlayer]
    let winnerNames: [String]
    let durationSeconds: Int

    var displayTitle: String {
        if let gameTitle, !gameTitle.isEmpty { return gameTitle }
        return MiniGameID(rawValue: gameId)?.title ?? "Game"
    }

    var headline: String {
        guard let first = winnerNames.first else { return scoreLine.isEmpty ? "Finished" : scoreLine }
        if winnerNames.count > 1 {
            return "Tie: \(winnerNames.joined(separator: " & "))"
        }
        return "\(first) won"
    }

    /// "Alex 3 · Sam 1" — empty scores omitted.
    var scoreLine: String {
        players
            .map { "\($0.displayName) \($0.score)" }
            .joined(separator: " · ")
    }

    var playerNames: String {
        players.map(\.displayName).joined(separator: ", ")
    }

    var durationLine: String {
        guard durationSeconds > 0 else { return "" }
        if durationSeconds < 60 { return "\(durationSeconds)s" }
        return "\(durationSeconds / 60)m \(durationSeconds % 60)s"
    }
}

@MainActor
@Observable
final class GameStatsStore {
    static let shared = GameStatsStore()
    private static let storageKey = "kiddo.gamestats.v1"

    private(set) var records: [GameMatchRecord] = []

    private init() {
        load()
    }

    /// Records a finished match and optionally banners the parent.
    @discardableResult
    func record(
        gameId: MiniGameID,
        players: [GamePlayer],
        winnerIds: [String],
        durationSeconds: Int,
        notifyParents: Bool = true
    ) -> GameMatchRecord {
        let winnerNames = players.filter { winnerIds.contains($0.id) }.map(\.displayName)
        let record = GameMatchRecord(
            id: UUID().uuidString,
            gameId: gameId.rawValue,
            gameTitle: gameId.title,
            playedAt: Date(),
            players: players,
            winnerNames: winnerNames,
            durationSeconds: durationSeconds
        )
        records.insert(record, at: 0)
        if records.count > 100 { records = Array(records.prefix(100)) }
        save()

        if notifyParents {
            let event = FamilyChangeEvent(
                kind: .miniGamePlayed,
                childName: parentFacingWho(record),
                detail: gameId.title,
                extra: matchSummary(for: record)
            )
            LocalFamilyNotifier.notify([event], enabled: true)
        }
        return record
    }

    /// Who the parent should see first — prefer linked kids, else first player.
    private func parentFacingWho(_ record: GameMatchRecord) -> String {
        let names = record.players.map(\.displayName)
        if names.isEmpty { return "A kid" }
        if names.count == 1 { return names[0] }
        return names.prefix(2).joined(separator: " & ")
            + (names.count > 2 ? " +\(names.count - 2)" : "")
    }

    /// Short parent-facing summary: scores + who won.
    private func matchSummary(for record: GameMatchRecord) -> String {
        var parts: [String] = []
        if !record.scoreLine.isEmpty { parts.append(record.scoreLine) }
        if record.winnerNames.isEmpty {
            if record.players.count > 1 { parts.append("no winner") }
        } else if record.winnerNames.count > 1 {
            parts.append("tie: \(record.winnerNames.joined(separator: " & "))")
        } else if let winner = record.winnerNames.first {
            parts.append("\(winner) won")
        }
        return parts.joined(separator: " · ")
    }

    var recent: [GameMatchRecord] { Array(records.prefix(5)) }

    /// Aggregate wins by display name (custom names count too).
    func topWinners(limit: Int = 5) -> [(name: String, wins: Int)] {
        var counts: [String: Int] = [:]
        for record in records {
            for name in record.winnerNames where !name.isEmpty {
                counts[name, default: 0] += 1
            }
        }
        var rows: [(name: String, wins: Int)] = []
        for (name, wins) in counts {
            rows.append((name: name, wins: wins))
        }
        rows.sort { lhs, rhs in
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            return lhs.name < rhs.name
        }
        if rows.count > limit {
            rows = Array(rows.prefix(limit))
        }
        return rows
    }

    func matches(for gameId: MiniGameID) -> [GameMatchRecord] {
        records.filter { $0.gameId == gameId.rawValue }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([GameMatchRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Pass device

struct PassDeviceCard: View {
    let playerName: String
    let colorHex: String
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Pass to")
                .font(KiddoTasksDesignTokens.Typography.titleMedium)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            Text(playerName)
                .font(KiddoTasksDesignTokens.Typography.displayLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            Circle()
                .fill(Color(hex: colorHex).opacity(0.2))
                .frame(width: 72, height: 72)
                .overlay(Text(String(playerName.prefix(1))).font(.largeTitle.bold()).foregroundStyle(Color(hex: colorHex)))
            Spacer()
            PrimaryButton(title: "I'm ready") { onReady() }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiddoTasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())
    }
}

// MARK: - Result chrome

struct GameResultView: View {
    let title: String
    let message: String
    let players: [GamePlayer]
    let winnerIds: [String]
    let onRematch: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(title)
                .font(KiddoTasksDesignTokens.Typography.displayMedium)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
            Text(message)
                .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(players.sorted { $0.score > $1.score }) { p in
                    HStack {
                        Circle()
                            .fill(Color(hex: p.colorHex).opacity(0.25))
                            .frame(width: 36, height: 36)
                            .overlay(Text(String(p.displayName.prefix(1))).foregroundStyle(Color(hex: p.colorHex)))
                        Text(p.displayName)
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        Spacer()
                        if winnerIds.contains(p.id) {
                            Text("Winner")
                                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(KiddoTasksDesignTokens.Colors.successLight))
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.success)
                        }
                        Text("\(p.score)")
                            .font(KiddoTasksDesignTokens.Typography.titleMedium)
                            .monospacedDigit()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                }
            }
            .padding(.horizontal, 20)

            Spacer()
            PrimaryButton(title: "Play again", action: onRematch)
                .padding(.horizontal, 32)
            SecondaryButton(title: "Back to games", action: onExit)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiddoTasksDesignTokens.PageBackgrounds.parentPage.ignoresSafeArea())
    }
}
