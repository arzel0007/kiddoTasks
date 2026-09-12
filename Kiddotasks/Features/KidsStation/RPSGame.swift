import SwiftUI

enum RPSMove: String, CaseIterable, Identifiable {
    case rock, paper, scissors
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rock: return "Rock"
        case .paper: return "Paper"
        case .scissors: return "Scissors"
        }
    }
    var glyph: String {
        switch self {
        case .rock: return "✊"
        case .paper: return "✋"
        case .scissors: return "✌️"
        }
    }

    func beats(_ other: RPSMove) -> Bool {
        switch (self, other) {
        case (.rock, .scissors), (.paper, .rock), (.scissors, .paper): return true
        default: return false
        }
    }
}

@MainActor
@Observable
final class RPSEngine {
    var round = 1
    var maxRounds = 3
    var p1Score = 0
    var p2Score = 0
    var p1Move: RPSMove?
    var p2Move: RPSMove?
    var roundMessage: String?
    var isOver: Bool { p1Score >= winsNeeded || p2Score >= winsNeeded }

    private var winsNeeded: Int { maxRounds / 2 + 1 }

    func play(m1: RPSMove, m2: RPSMove) {
        p1Move = m1
        p2Move = m2
        if m1.beats(m2) {
            p1Score += 1
            roundMessage = "\(m1.title) beats \(m2.title)"
            Haptic.success()
        } else if m2.beats(m1) {
            p2Score += 1
            roundMessage = "\(m2.title) beats \(m1.title)"
            Haptic.success()
        } else {
            roundMessage = "Tie — both \(m1.title)"
            Haptic.light()
        }
    }

    func nextRound() {
        round += 1
        p1Move = nil
        p2Move = nil
        roundMessage = nil
    }

    func resetMatch() {
        round = 1
        p1Score = 0
        p2Score = 0
        p1Move = nil
        p2Move = nil
        roundMessage = nil
    }
}

struct RPSView: View {
    let players: [GamePlayer]
    var requirePassDevice = true
    let onExit: () -> Void

    @State private var engine = RPSEngine()
    @State private var isPickingP1 = true
    @State private var showResult = false
    @State private var matchOver = false
    @State private var startedAt = Date()
    @State private var showPass = false

    private var p1: GamePlayer {
        players.first ?? GamePlayer(displayName: "Player 1", colorHex: "#3978A8")
    }
    private var p2: GamePlayer {
        players.count > 1
            ? players[1]
            : GamePlayer(displayName: "Player 2", colorHex: "#D59A3A")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header
                Spacer()
                if showResult {
                    resultPanel
                } else {
                    pickPanel
                }
                Spacer()
                SecondaryButton(title: "End game") { finish() }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KiddoTasksDesignTokens.PageBackgrounds.kidsRewardPop.ignoresSafeArea())

            if showPass {
                PassDeviceCard(
                    playerName: isPickingP1 ? p1.displayName : p2.displayName,
                    colorHex: isPickingP1 ? p1.colorHex : p2.colorHex
                ) {
                    showPass = false
                }
                .transition(.opacity)
            }

            // Overlay (not fullScreenCover) — nested covers freeze inside Games hub.
            if matchOver {
                GameResultView(
                    title: engine.p1Score == engine.p2Score ? "Great match!" : "Nice game!",
                    message: "\(p1.displayName) \(engine.p1Score) — \(engine.p2Score) \(p2.displayName)",
                    players: resultPlayers(),
                    winnerIds: winnerIds(),
                    onRematch: {
                        matchOver = false
                        engine.resetMatch()
                        isPickingP1 = true
                        showResult = false
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
        a.score = engine.p1Score
        var b = p2
        b.score = engine.p2Score
        return [a, b]
    }

    private func winnerIds() -> [String] {
        if engine.p1Score == engine.p2Score { return [] }
        return engine.p1Score > engine.p2Score ? [p1.id] : [p2.id]
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Rock · Paper · Scissors")
                .font(KiddoTasksDesignTokens.Typography.headingMedium)
            Text("Round \(engine.round) of \(engine.maxRounds) · \(p1.displayName) \(engine.p1Score) — \(engine.p2Score) \(p2.displayName)")
                .font(KiddoTasksDesignTokens.Typography.captionLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
        }
        .padding(.top, 20)
    }

    private var pickPanel: some View {
        VStack(spacing: 16) {
            Text(isPickingP1 ? "\(p1.displayName)'s pick" : "\(p2.displayName)'s pick")
                .font(KiddoTasksDesignTokens.Typography.titleLarge)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                ForEach(RPSMove.allCases) { move in
                    Button {
                        Haptic.light()
                        if isPickingP1 {
                            engine.p1Move = move
                            isPickingP1 = false
                            if requirePassDevice { showPass = true }
                        } else {
                            engine.play(m1: engine.p1Move ?? .rock, m2: move)
                            showResult = true
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Text(move.glyph).font(.system(size: 48))
                            Text(move.title)
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(KiddoTasksDesignTokens.Colors.borderSubtle, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(ExtraBouncyPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var resultPanel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(engine.p1Move?.glyph ?? "❓").font(.system(size: 56))
                    Text(p1.displayName)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
                Text("vs")
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textTertiary)
                VStack(spacing: 8) {
                    Text(engine.p2Move?.glyph ?? "❓").font(.system(size: 56))
                    Text(p2.displayName)
                        .font(KiddoTasksDesignTokens.Typography.captionLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                }
            }
            Text(engine.roundMessage ?? "")
                .font(KiddoTasksDesignTokens.Typography.titleMedium)
                .multilineTextAlignment(.center)
            if engine.isOver {
                PrimaryButton(title: "See results") { finish() }
                    .padding(.horizontal, 40)
            } else {
                PrimaryButton(title: "Next round") {
                    engine.nextRound()
                    isPickingP1 = true
                    showResult = false
                }
                .padding(.horizontal, 40)
            }
        }
        .padding(.horizontal, 16)
    }

    private func finish() {
        GameStatsStore.shared.record(
            gameId: .rps,
            players: resultPlayers(),
            winnerIds: winnerIds(),
            durationSeconds: Int(Date().timeIntervalSince(startedAt))
        )
        matchOver = true
    }
}
