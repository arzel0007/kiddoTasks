import SwiftUI

// MARK: - Player setup (shared)

struct GamePlayerSetupView: View {
    let game: MiniGameID
    let onStart: ([GamePlayer], MemoryBoardSize) -> Void
    let onCancel: () -> Void

    @Environment(AppState.self) private var appState
    @State private var playerCount: Int
    @State private var seats: [Seat]
    @State private var boardSize: MemoryBoardSize = .four

    private struct Seat: Identifiable {
        let id = UUID()
        var childId: String?
        var customName: String
        var colorHex: String
    }

    private static let palette = ["#3978A8", "#3F8B70", "#D59A3A", "#D97868"]

    init(
        game: MiniGameID,
        onStart: @escaping ([GamePlayer], MemoryBoardSize) -> Void,
        onCancel: @escaping () -> Void
    ) {
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

                    if game == .memory {
                        boardSizeSection
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

    private var boardSizeSection: some View {
        KiddoFormSection(title: "Board size", icon: "square.grid.3x3.fill") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MemoryBoardSize.allCases) { size in
                            Button {
                                boardSize = size
                                Haptic.light()
                            } label: {
                                VStack(spacing: 2) {
                                    Text(size.label)
                                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                        .fontWeight(.bold)
                                    Text("\(size.pairCount) pairs")
                                        .font(KiddoTasksDesignTokens.Typography.captionSmall)
                                }
                                .frame(minWidth: 64, minHeight: 52)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            boardSize == size
                                                ? KiddoTasksDesignTokens.Colors.primary
                                                : KiddoTasksDesignTokens.Colors.surface
                                        )
                                )
                                .foregroundStyle(boardSize == size ? .white : KiddoTasksDesignTokens.Colors.text)
                            }
                            .buttonStyle(KiddoPressStyle())
                            .accessibilityLabel("\(size.label) board, \(size.detail)")
                        }
                    }
                }
                Text(boardSize.detail)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
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
        onStart(players, boardSize)
    }
}

// MARK: - Games hub

/// Bundle so the cover cannot open with empty players (race with separate @State).
private struct GameLaunch: Identifiable {
    let id = UUID()
    let game: MiniGameID
    let players: [GamePlayer]
    var boardSize: MemoryBoardSize = .four
}

struct GamesHubView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedGame: MiniGameID?
    @State private var launch: GameLaunch?

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
                            selectedGame = game
                        } label: {
                            HStack(spacing: 14) {
                                Text(game.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(hex: game.accentHex).opacity(0.18))
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.title)
                                        .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                                    Text(game.subtitle)
                                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                                }
                                Spacer()
                                Text("PLAY")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color(hex: game.accentHex)))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(KiddoTasksDesignTokens.Colors.borderSubtle))
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
                GamePlayerSetupView(game: game) { players, boardSize in
                    selectedGame = nil
                    // Present after the sheet finishes dismissing (same-runloop race).
                    // Players ride inside GameLaunch so the cover never sees [].
                    let payload = GameLaunch(game: game, players: players, boardSize: boardSize)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        launch = payload
                    }
                } onCancel: {
                    selectedGame = nil
                }
            }
            .fullScreenCover(item: $launch) { item in
                MiniGameHostView(
                    game: item.game,
                    players: item.players,
                    memoryBoardSize: item.boardSize
                ) {
                    launch = nil
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
                    Text("• \(rec.headline) · \(rec.displayTitle)")
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
    var memoryBoardSize: MemoryBoardSize = .four
    let onExit: () -> Void

    /// Never crash on empty roster — fall back to guest seats.
    private var safePlayers: [GamePlayer] {
        if !players.isEmpty { return players }
        let needed = max(2, game.minPlayers)
        return (0..<needed).map { i in
            GamePlayer(
                displayName: "Player \(i + 1)",
                colorHex: ["#3978A8", "#3F8B70", "#D59A3A", "#D97868"][i % 4],
                symbol: ["✕", "○", "△", "□"][i % 4]
            )
        }
    }

    var body: some View {
        Group {
            switch game {
            case .tictactoe:
                TicTacToeView(players: safePlayers, requirePassDevice: true, onExit: onExit)
            case .memory:
                MemoryGameView(
                    players: safePlayers,
                    boardSize: memoryBoardSize,
                    requirePassDevice: false,
                    onExit: onExit
                )
            case .snakes:
                SnakesLaddersView(players: safePlayers, onExit: onExit)
            case .connect4:
                Connect4View(players: safePlayers, onExit: onExit)
            case .whack:
                WhackAMoleView(players: safePlayers, onExit: onExit)
            case .balloon:
                BalloonPopView(players: safePlayers, onExit: onExit)
            case .sudoku:
                SudokuView(players: safePlayers, onExit: onExit)
            }
        }
    }
}
