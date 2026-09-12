import SwiftUI

// MARK: - Player setup (shared)

struct GamePlayerSetupView: View {
    let game: MiniGameID
    let onStart: ([GamePlayer]) -> Void
    let onCancel: () -> Void

    @Environment(AppState.self) private var appState
    @State private var playerCount: Int
    @State private var seats: [Seat]

    private struct Seat: Identifiable {
        let id = UUID()
        var childId: String?
        var customName: String
        var colorHex: String
    }

    private static let palette = ["#3978A8", "#3F8B70", "#D59A3A", "#D97868"]

    init(game: MiniGameID, onStart: @escaping ([GamePlayer]) -> Void, onCancel: @escaping () -> Void) {
        self.game = game
        self.onStart = onStart
        self.onCancel = onCancel
        let count = max(game.minPlayers, min(2, game.maxPlayers))
        let palette = Self.palette
        _playerCount = State(initialValue: count)
        _seats = State(initialValue: (0..<count).map { i in
            Seat(childId: nil, customName: "Player \(i + 1)", colorHex: palette[i % palette.count])
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if game.maxPlayers > 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How many players?")
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            HStack(spacing: 8) {
                                ForEach(2...game.maxPlayers, id: \.self) { n in
                                    Button {
                                        resize(to: n)
                                    } label: {
                                        Text("\(n)")
                                            .fontWeight(.bold)
                                            .frame(minWidth: 44, minHeight: 44)
                                            .background(
                                                Circle().fill(
                                                    playerCount == n
                                                        ? KiddoTasksDesignTokens.Colors.primary
                                                        : KiddoTasksDesignTokens.Colors.surface
                                                )
                                            )
                                            .foregroundStyle(playerCount == n ? .white : KiddoTasksDesignTokens.Colors.text)
                                    }
                                    .buttonStyle(KiddoPressStyle())
                                }
                            }
                        }
                    }

                    ForEach(Array(seats.enumerated()), id: \.element.id) { index, seat in
                        seatEditor(index: index)
                    }

                    PrimaryButton(title: "Start \(game.title)") {
                        start()
                    }
                }
                .padding(20)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.parentPage)
            .navigationTitle("Who's playing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    @ViewBuilder
    private func seatEditor(index: Int) -> some View {
        let kids = appState.familyChildren
        KiddoFormSection(title: "Player \(index + 1)", icon: "person.fill") {
            if !kids.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(kids) { kid in
                            Button {
                                seats[index].childId = kid.id
                                seats[index].customName = kid.name
                                seats[index].colorHex = kid.avatar.colorHex
                            } label: {
                                HStack(spacing: 6) {
                                    ChildAvatarView(avatar: kid.avatar, size: 28, photoData: kid.photoData, photoURL: kid.photoURL)
                                    Text(kid.name)
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        seats[index].childId == kid.id
                                            ? KiddoTasksDesignTokens.Colors.primaryLight
                                            : KiddoTasksDesignTokens.Colors.surface
                                    )
                                )
                            }
                            .buttonStyle(KiddoPressStyle())
                        }
                    }
                }
            }
            KiddoTextField(label: "Name", placeholder: "Player \(index + 1)", text: Binding(
                get: { seats[index].customName },
                set: { seats[index].customName = $0; seats[index].childId = nil }
            ))
        }
    }

    private func resize(to n: Int) {
        playerCount = n
        if n < seats.count {
            seats = Array(seats.prefix(n))
        } else {
            while seats.count < n {
                let i = seats.count
                seats.append(Seat(childId: nil, customName: "Player \(i + 1)", colorHex: Self.palette[i % Self.palette.count]))
            }
        }
        Haptic.light()
    }

    private func start() {
        let symbols = ["✕", "○", "△", "□"]
        let players = seats.enumerated().map { i, seat -> GamePlayer in
            let name = seat.customName.trimmingCharacters(in: .whitespaces)
            return GamePlayer(
                displayName: name.isEmpty ? "Player \(i + 1)" : name,
                childId: seat.childId,
                colorHex: seat.colorHex,
                symbol: symbols[i % symbols.count]
            )
        }
        onStart(players)
    }
}

// MARK: - Games hub

struct GamesHubView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedGame: MiniGameID?
    @State private var startGame: MiniGameID?
    @State private var pendingPlayers: [GamePlayer] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Pick a game — no need to choose a kid first")
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        Spacer()
                        if appState.currentChildProfile == nil {
                            Button("Parent") {
                                appState.exitGamesMode()
                            }
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard.opacity(0.85)))
                            .buttonStyle(KiddoPressStyle())
                            .accessibilityLabel("Back to Parent Center")
                        }
                    }

                    ForEach(MiniGameID.allCases) { game in
                        Button {
                            // Basketball has its own in-game player menu — skip setup sheet.
                            if game == .basketball {
                                startGame = .basketball
                                pendingPlayers = []
                            } else {
                                selectedGame = game
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: game.symbol)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: game.accentHex)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.title)
                                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                    Text(game.subtitle)
                                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(KiddoTasksDesignTokens.Colors.borderSubtle))
                        }
                        .buttonStyle(CardPressStyle())
                    }

                    statsSection
                }
                .padding(16)
            }
            .kiddoPageBackground(KiddoTasksDesignTokens.PageBackgrounds.kidsPlayground)
            .navigationTitle("Games")
            .sheet(item: $selectedGame) { game in
                GamePlayerSetupView(game: game) { players in
                    selectedGame = nil
                    // Present the full-screen game only after the sheet has
                    // finished dismissing — same-runloop sheet→cover races
                    // silently fail (game "doesn't launch").
                    let playersCopy = players
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        pendingPlayers = playersCopy
                        startGame = game
                    }
                } onCancel: {
                    selectedGame = nil
                }
            }
            .fullScreenCover(item: $startGame) { game in
                MiniGameHostView(game: game, players: pendingPlayers) {
                    startGame = nil
                    pendingPlayers = []
                }
            }
        }
    }

    private var statsSection: some View {
        let store = GameStatsStore.shared
        return VStack(alignment: .leading, spacing: 10) {
            Text("Game dashboard")
                .font(KiddoTasksDesignTokens.Typography.titleSmall)
            let tops = store.topWinners(limit: 3)
            if store.records.isEmpty {
                Text("No games yet — start one!")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            } else {
                Text("Played \(store.records.count) games")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                ForEach(tops, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .font(KiddoTasksDesignTokens.Typography.bodyMedium)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(row.wins) wins")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    }
                }
                ForEach(store.recent) { rec in
                    Text("• \(rec.headline) · \(rec.gameId)")
                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
    }
}

// MARK: - Host

struct MiniGameHostView: View {
    let game: MiniGameID
    let players: [GamePlayer]
    let onExit: () -> Void

    var body: some View {
        Group {
            switch game {
            case .tictactoe:
                TicTacToeView(players: players, requirePassDevice: true, onExit: onExit)
            case .rps:
                RPSView(players: players, requirePassDevice: true, onExit: onExit)
            case .memory:
                MemoryGameView(players: players, requirePassDevice: false, onExit: onExit)
            case .basketball:
                BasketballGameView(onExit: onExit)
            }
        }
    }
}
