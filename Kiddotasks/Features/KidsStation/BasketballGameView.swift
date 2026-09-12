import SwiftUI

/// Basketball Challenge — swipe-to-shoot mini-game inside Kids Space.
struct BasketballGameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when the user leaves the game entirely (Games hub exit).
    var onExit: (() -> Void)? = nil

    @State private var engine = BasketballGameEngine()
    @State private var showPlayerPicker = false
    @State private var pickingSlot = 1
    @State private var physicsTask: Task<Void, Never>?

    private var children: [Child] { appState.familyChildren }
    private var currentChild: Child? {
        guard let id = appState.currentChildProfile?.id else { return nil }
        return appState.child(id: id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                courtBackground

                switch engine.phase {
                case .menu:
                    menuView
                case .selectPlayers:
                    playerSelectView
                case .countdown:
                    courtCanvas
                    countdownOverlay
                case .playing:
                    courtCanvas
                    hudOverlay
                case .gameOver:
                    courtCanvas
                    gameOverOverlay
                }
            }
            .navigationTitle("Basketball")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        leaveGame()
                    }
                }
            }
            .sheet(isPresented: $showPlayerPicker) {
                playerPickerSheet
            }
        }
        .onAppear {
            engine.bestSoloScore = UserDefaults.standard.integer(forKey: "kiddo.bball.best")
            applyParentTimeLimit()
            startPhysicsLoop()
        }
        .onDisappear {
            physicsTask?.cancel()
            physicsTask = nil
        }
        .onChange(of: engine.phase) { _, phase in
            if phase == .gameOver, engine.mode == .solo {
                let best = max(engine.bestSoloScore, engine.stats1.score)
                engine.bestSoloScore = best
                UserDefaults.standard.set(best, forKey: "kiddo.bball.best")
            }
        }
    }

    private func leaveGame() {
        physicsTask?.cancel()
        physicsTask = nil
        engine.returnToMenu()
        if let onExit {
            onExit()
        }
    }

    /// Physics off the TimelineView callback — mutating @Observable state from
    /// `.onChange(of: timeline.date)` every frame freezes the main thread.
    private func startPhysicsLoop() {
        physicsTask?.cancel()
        physicsTask = Task { @MainActor in
            while !Task.isCancelled {
                if engine.phase == .playing {
                    engine.step(dt: 1.0 / 60.0)
                }
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    // MARK: - Background

    private var courtBackground: some View {
        KiddoTasksDesignTokens.PageBackgrounds.kidsMissionSky
            .ignoresSafeArea()
    }

    // MARK: - Menu

    private var menuView: some View {
        ScrollView {
            VStack(spacing: KiddoTasksDesignTokens.Spacing.large) {
                VStack(spacing: 8) {
                    Text("🏀")
                        .font(.system(size: 64))
                    Text("Basketball Challenge")
                        .font(KiddoTasksDesignTokens.Typography.displaySmall)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    Text("How many baskets can you make?")
                        .font(KiddoTasksDesignTokens.Typography.bodyLarge)
                        .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                PrimaryButton(title: "1 Player", color: KiddoTasksDesignTokens.Colors.primary) {
                    applyParentTimeLimit()
                    engine.startSolo(child: currentChild)
                }

                PrimaryButton(title: "2 Players", color: KiddoTasksDesignTokens.Colors.accent) {
                    applyParentTimeLimit()
                    engine.phase = .selectPlayers
                }

                if children.count >= 3 {
                    SecondaryButton(title: "Tournament (\(min(children.count, 4)) players)") {
                        applyParentTimeLimit()
                        let roster = children.prefix(4).map {
                            BasketballPlayer(childId: $0.id, name: $0.name, accentHex: $0.avatar.colorHex)
                        }
                        engine.startTournament(players: Array(roster))
                    }
                }

                if engine.bestSoloScore > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.warning)
                        Text("Best score: \(engine.bestSoloScore)")
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(KiddoTasksDesignTokens.Colors.surfaceCard))
                }

                Text("Drag the ball to aim, flick up to shoot. Beat the clock!")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer(minLength: 24)
            }
            .padding(KiddoTasksDesignTokens.Spacing.xLarge)
        }
    }

    // MARK: - 2P select

    private var playerSelectView: some View {
        VStack(spacing: KiddoTasksDesignTokens.Spacing.medium) {
            Text("Who's playing?")
                .font(KiddoTasksDesignTokens.Typography.headingLarge)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                .padding(.top, 16)

            HStack(spacing: 12) {
                playerSlotCard(title: "Player 1", player: engine.player1, slot: 1)
                playerSlotCard(title: "Player 2", player: engine.player2, slot: 2)
            }
            .padding(.horizontal)

            if children.isEmpty {
                Text("Add kids in the Family tab, or play with default names.")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            PrimaryButton(title: "Start game") {
                engine.startVersus(p1: engine.player1, p2: engine.player2)
            }
            .padding(.horizontal)

            SecondaryButton(title: "Back") {
                engine.phase = .menu
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func playerSlotCard(title: String, player: BasketballPlayer, slot: Int) -> some View {
        Button {
            pickingSlot = slot
            showPlayerPicker = true
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
                Circle()
                    .fill(player.accent.opacity(0.25))
                    .frame(width: 64, height: 64)
                    .overlay(Text(String(player.name.prefix(1))).font(.title).foregroundStyle(player.accent))
                Text(player.name)
                    .font(KiddoTasksDesignTokens.Typography.titleSmall)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(KiddoTasksDesignTokens.Colors.surfaceCard))
        }
        .buttonStyle(CardPressStyle())
    }

    private var playerPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(children) { child in
                    Button {
                        let p = BasketballPlayer(
                            childId: child.id,
                            name: child.name,
                            accentHex: child.avatar.colorHex
                        )
                        if pickingSlot == 1 { engine.player1 = p } else { engine.player2 = p }
                        showPlayerPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            ChildAvatarView(avatar: child.avatar, size: 40, photoData: child.photoData, photoURL: child.photoURL)
                            Text(child.name)
                                .font(KiddoTasksDesignTokens.Typography.titleSmall)
                                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
                        }
                    }
                }
            }
            .navigationTitle("Pick a player")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPlayerPicker = false }
                }
            }
        }
    }

    // MARK: - Court + HUD

    private var courtCanvas: some View {
        GeometryReader { geo in
            let size = geo.size
            // TimelineView drives rendering only — physics runs in startPhysicsLoop().
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: engine.phase != .playing && engine.phase != .countdown)) { _ in
                Canvas { context, canvasSize in
                    drawCourt(context: &context, size: canvasSize)
                    drawGuide(context: &context, size: canvasSize)
                    drawHoop(context: &context, size: canvasSize)
                    drawBall(context: &context, size: canvasSize, accent: engine.activePlayer.accent)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = CGPoint(
                            x: value.location.x / max(size.width, 1),
                            y: value.location.y / max(size.height, 1)
                        )
                        if !engine.isDragging && !engine.isFlying {
                            engine.beginDrag(at: p)
                        } else if engine.isDragging {
                            engine.updateDrag(at: p)
                        }
                    }
                    .onEnded { value in
                        let p = CGPoint(
                            x: value.location.x / max(size.width, 1),
                            y: value.location.y / max(size.height, 1)
                        )
                        engine.updateDrag(at: p)
                        engine.endDrag()
                    }
            )
            .disabled(engine.phase != .playing)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func drawCourt(context: inout GraphicsContext, size: CGSize) {
        // Floor band
        let floor = CGRect(x: 0, y: size.height * 0.78, width: size.width, height: size.height * 0.22)
        context.fill(Path(floor), with: .color(colorScheme == .dark ? Color(white: 0.14) : Color(hex: "#D6C4A8")))
        // Center line
        var line = Path()
        line.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.78))
        line.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
        context.stroke(line, with: .color(.white.opacity(0.25)), lineWidth: 2)
    }

    private func drawGuide(context: inout GraphicsContext, size: CGSize) {
        guard engine.isDragging, !engine.guidePoints.isEmpty else { return }
        let path = Path { p in
            for (i, pt) in engine.guidePoints.enumerated() {
                let cg = CGPoint(x: pt.x * size.width, y: pt.y * size.height)
                if i == 0 { p.move(to: cg) } else { p.addLine(to: cg) }
            }
        }
        context.stroke(
            path,
            with: .color(engine.activePlayer.accent.opacity(0.55)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8])
        )
    }

    private func drawHoop(context: inout GraphicsContext, size: CGSize) {
        let hx = BasketballGameEngine.hoopX * size.width
        let hy = BasketballGameEngine.hoopY * size.height
        let rw = BasketballGameEngine.rimHalfWidth * size.width
        let rh = BasketballGameEngine.rimHalfHeight * size.height
        let boardW = BasketballGameEngine.backboardHalfWidth * size.width

        // Backboard (centered behind rim — front-facing)
        let board = CGRect(
            x: hx - boardW,
            y: hy - size.height * 0.11,
            width: boardW * 2,
            height: size.height * 0.10
        )
        context.fill(
            Path(roundedRect: board, cornerRadius: 6),
            with: .color(colorScheme == .dark ? Color(white: 0.78) : .white)
        )
        context.stroke(
            Path(roundedRect: board, cornerRadius: 6),
            with: .color(colorScheme == .dark ? Color(white: 0.45) : Color(white: 0.75)),
            lineWidth: 2
        )
        // Target square on board
        let square = CGRect(
            x: hx - rw * 0.55,
            y: hy - size.height * 0.07,
            width: rw * 1.1,
            height: size.height * 0.04
        )
        context.stroke(
            Path(roundedRect: square, cornerRadius: 2),
            with: .color(Color(hex: "#F97316").opacity(0.85)),
            lineWidth: 2
        )

        // Rim: front-facing ellipse (ring faces the player)
        let rimRect = CGRect(x: hx - rw, y: hy - rh, width: rw * 2, height: rh * 2)
        let rimPath = Path(ellipseIn: rimRect)
        context.stroke(
            rimPath,
            with: .color(Color(hex: "#F97316").opacity(0.35 + engine.rimHitFlash * 0.65)),
            style: StrokeStyle(lineWidth: 7 + engine.rimHitFlash * 3, lineCap: .round)
        )
        // Inner opening hint
        let inner = CGRect(
            x: hx - rw * 0.72,
            y: hy - rh * 0.72,
            width: rw * 1.44,
            height: rh * 1.44
        )
        context.fill(Path(ellipseIn: inner), with: .color(.black.opacity(colorScheme == .dark ? 0.35 : 0.12)))

        // Net below opening
        var net = Path()
        for i in 0...6 {
            let t = CGFloat(i) / 6
            let x = hx - rw * 0.7 + rw * 1.4 * t
            net.move(to: CGPoint(x: x, y: hy + rh * 0.5))
            net.addLine(to: CGPoint(x: hx + (x - hx) * 0.3, y: hy + size.height * 0.09))
        }
        context.stroke(net, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        // Net bottom ring
        let netBottom = CGRect(
            x: hx - rw * 0.28,
            y: hy + size.height * 0.08,
            width: rw * 0.56,
            height: rh * 0.6
        )
        context.stroke(Path(ellipseIn: netBottom), with: .color(.white.opacity(0.8)), lineWidth: 1.5)

        // Pole
        var pole = Path()
        pole.move(to: CGPoint(x: hx, y: board.maxY))
        pole.addLine(to: CGPoint(x: hx, y: size.height * 0.78))
        context.stroke(pole, with: .color(colorScheme == .dark ? Color(white: 0.4) : Color(white: 0.55)), lineWidth: 6)
    }

    private func drawBall(context: inout GraphicsContext, size: CGSize, accent: Color) {
        let r = BasketballGameEngine.ballRadius * min(size.width, size.height)
        let c = CGPoint(x: engine.ballX * size.width, y: engine.ballY * size.height)
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#E67E22")))
        context.stroke(Path(ellipseIn: rect), with: .color(Color(hex: "#B85C12")), lineWidth: 2)
        // Seam
        var seam = Path()
        seam.move(to: CGPoint(x: c.x - r, y: c.y))
        seam.addLine(to: CGPoint(x: c.x + r, y: c.y))
        context.stroke(seam, with: .color(.black.opacity(0.35)), lineWidth: 1.5)
        if engine.isDragging {
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)), with: .color(accent.opacity(0.45)), lineWidth: 3)
        }
    }

    private var hudOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle().fill(engine.activePlayer.accent).frame(width: 12, height: 12)
                        Text(engine.activePlayer.name)
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.25)))

                    if engine.mode == .versus {
                        Text("\(engine.player1.name) \(engine.stats1.score)  ·  \(engine.player2.name) \(engine.stats2.score)")
                            .font(KiddoTasksDesignTokens.Typography.captionLarge)
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.black.opacity(0.2)))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(engine.activeStats.score)")
                        .font(KiddoTasksDesignTokens.Typography.displayLarge)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(engine.formattedClock)
                        .font(KiddoTasksDesignTokens.Typography.titleMedium)
                        .monospacedDigit()
                        .fontWeight(.bold)
                        .foregroundStyle(engine.activeTimeRemaining <= 10 ? KiddoTasksDesignTokens.Colors.error : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.3)))
                    if engine.mode == .versus {
                        Text("\(engine.player1.name) \(engine.stats1.score) · \(engine.player2.name) \(engine.stats2.score)")
                            .font(KiddoTasksDesignTokens.Typography.captionSmall)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    if engine.activeStats.streak >= 2 {
                        Text("🔥 \(engine.activeStats.streak)")
                            .font(KiddoTasksDesignTokens.Typography.titleSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#F97316")))
                    }
                }
            }
            .padding()

            Spacer()

            if let msg = engine.flashMessage {
                Text(msg)
                    .font(KiddoTasksDesignTokens.Typography.headingMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 36)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.flashMessage)
    }

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            Text(engine.countdownValue > 0 ? "\(engine.countdownValue)" : "🏀")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(engine.mode == .versus ? versusResultTitle : "🎉 Great Game!")
                    .font(KiddoTasksDesignTokens.Typography.displaySmall)
                    .foregroundStyle(.white)

                if engine.mode == .solo {
                    resultStatRow(label: "Score", value: "\(engine.stats1.score)")
                    resultStatRow(label: "Shots", value: "\(engine.stats1.made)/\(engine.stats1.attempted)")
                    resultStatRow(label: "Accuracy", value: "\(engine.stats1.accuracy)%")
                    resultStatRow(label: "Best streak", value: "🔥 \(engine.stats1.bestStreak)")
                    if engine.stats1.score >= engine.bestSoloScore && engine.stats1.score > 0 {
                        Text("🏆 NEW BEST SCORE!")
                            .font(KiddoTasksDesignTokens.Typography.titleMedium)
                            .foregroundStyle(KiddoTasksDesignTokens.Colors.warning)
                    }
                } else {
                    versusResultCard(engine.player1, engine.stats1)
                    versusResultCard(engine.player2, engine.stats2)
                }

                PrimaryButton(title: "Play again") {
                    if engine.mode == .solo {
                        engine.startSolo(child: currentChild)
                    } else {
                        engine.startVersus(p1: engine.player1, p2: engine.player2)
                    }
                }
                SecondaryButton(title: "Back to menu") {
                    engine.returnToMenu()
                }
                if onExit != nil {
                    SecondaryButton(title: "Back to games") {
                        leaveGame()
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(KiddoTasksDesignTokens.Colors.surfaceCard)
            )
            .padding(24)
        }
    }

    private func applyParentTimeLimit() {
        let minutes = appState.currentFamily?.settings.basketballMaxMinutes ?? 0
        engine.configureClocks(parentMaxMinutes: minutes)
    }

    private var versusResultTitle: String {
        if engine.stats1.score > engine.stats2.score {
            return "🏆 \(engine.player1.name) wins!"
        }
        if engine.stats2.score > engine.stats1.score {
            return "🏆 \(engine.player2.name) wins!"
        }
        return "🤝 IT'S A TIE!"
    }

    private func resultStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
        }
        .font(KiddoTasksDesignTokens.Typography.bodyLarge)
    }

    private func versusResultCard(_ player: BasketballPlayer, _ stats: BasketballStats) -> some View {
        HStack {
            Circle().fill(player.accent.opacity(0.3)).frame(width: 36, height: 36)
                .overlay(Text(String(player.name.prefix(1))).foregroundStyle(player.accent))
            VStack(alignment: .leading) {
                Text(player.name).font(KiddoTasksDesignTokens.Typography.titleSmall)
                Text("\(stats.made)/\(stats.attempted) · \(stats.accuracy)%")
                    .font(KiddoTasksDesignTokens.Typography.captionLarge)
                    .foregroundStyle(KiddoTasksDesignTokens.Colors.textSecondary)
            }
            Spacer()
            Text("\(stats.score)")
                .font(KiddoTasksDesignTokens.Typography.displaySmall)
                .monospacedDigit()
                .foregroundStyle(KiddoTasksDesignTokens.Colors.text)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(KiddoTasksDesignTokens.Colors.surfaceElevated))
    }
}
