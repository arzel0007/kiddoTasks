import SwiftUI

// MARK: - Models

enum BasketballPhase: Equatable {
    case menu
    case selectPlayers
    case countdown
    case playing
    case gameOver
}

enum BasketballMode: Equatable {
    case solo
    case versus
}

struct BasketballPlayer: Equatable {
    let childId: String?
    let name: String
    let accentHex: String

    var accent: Color { Color(hex: accentHex) }

    init(childId: String?, name: String, accentHex: String) {
        self.childId = childId
        self.name = name
        self.accentHex = accentHex
    }

    init(name: String, accentHex: String) {
        self.init(childId: nil, name: name, accentHex: accentHex)
    }

    static let guest = BasketballPlayer(childId: nil, name: "Player", accentHex: "#6366F1")
}

struct BasketballStats: Equatable {
    var score = 0
    var made = 0
    var attempted = 0
    var streak = 0
    var bestStreak = 0

    var accuracy: Int {
        guard attempted > 0 else { return 0 }
        return Int((Double(made) / Double(attempted) * 100).rounded())
    }
}

// MARK: - Engine

/// Front-facing hoop, solid rim bounces, swipe-to-shoot, shot clock.
@MainActor
@Observable
final class BasketballGameEngine {
    // Phases
    var phase: BasketballPhase = .menu
    var mode: BasketballMode = .solo
    var countdownValue = 3

    // Players
    var player1 = BasketballPlayer.guest
    var player2 = BasketballPlayer(name: "Player 2", accentHex: "#EC4899")
    var activePlayerIndex = 0

    // Stats
    var stats1 = BasketballStats()
    var stats2 = BasketballStats()
    var bestSoloScore = 0

    // Clocks (seconds remaining while that player is active)
    var soloTimeRemaining: TimeInterval = 60
    var p1TimeRemaining: TimeInterval = 45
    var p2TimeRemaining: TimeInterval = 45
    private let soloDuration: TimeInterval = 60
    private let turnDuration: TimeInterval = 45

    // Ball physics (normalized 0...1 court space)
    var ballX: CGFloat = 0.5
    var ballY: CGFloat = 0.82
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0
    var isFlying = false
    var isDragging = false
    /// Finger-follow: ball rides the finger while dragging.
    var dragStart: CGPoint = .zero
    var dragCurrent: CGPoint = .zero
    var guidePoints: [CGPoint] = []

    // Front-facing hoop (normalized). Rim is an ellipse; opening faces the player.
    static let hoopX: CGFloat = 0.50
    static let hoopY: CGFloat = 0.28
    static let rimHalfWidth: CGFloat = 0.11
    static let rimHalfHeight: CGFloat = 0.022
    static let backboardHalfWidth: CGFloat = 0.15
    static let ballRadius: CGFloat = 0.038

    // Feedback
    var flashMessage: String?
    var lastShotScored = false
    var celebrationLevel: Int = 0
    var rimHitFlash: CGFloat = 0

    // Constants
    private let gravity: CGFloat = 1.15
    private let maxLaunchSpeed: CGFloat = 1.9
    private let minLaunchSpeed: CGFloat = 0.45
    private let swipeGain: CGFloat = 2.6
    private let bounceRestitution: CGFloat = 0.62
    private var scoredThisFlight = false
    private var crossedAboveRim = false
    private var flightTime: CGFloat = 0
    private var clockAccumulator: TimeInterval = 0

    var activeStats: BasketballStats {
        get { activePlayerIndex == 0 ? stats1 : stats2 }
        set {
            if activePlayerIndex == 0 { stats1 = newValue } else { stats2 = newValue }
        }
    }

    var activePlayer: BasketballPlayer {
        activePlayerIndex == 0 ? player1 : player2
    }

    var activeTimeRemaining: TimeInterval {
        switch mode {
        case .solo: return soloTimeRemaining
        case .versus: return activePlayerIndex == 0 ? p1TimeRemaining : p2TimeRemaining
        }
    }

    var formattedClock: String {
        let t = max(0, Int(activeTimeRemaining.rounded(.up)))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    // MARK: - Lifecycle

    func startSolo(child: Child?) {
        mode = .solo
        if let child {
            player1 = BasketballPlayer(
                childId: child.id,
                name: child.name,
                accentHex: child.avatar.colorHex
            )
        } else {
            player1 = .guest
        }
        stats1 = BasketballStats()
        stats2 = BasketballStats()
        activePlayerIndex = 0
        soloTimeRemaining = soloDuration
        beginCountdown()
    }

    func startVersus(p1: BasketballPlayer, p2: BasketballPlayer) {
        mode = .versus
        player1 = p1
        player2 = p2
        stats1 = BasketballStats()
        stats2 = BasketballStats()
        activePlayerIndex = 0
        p1TimeRemaining = turnDuration
        p2TimeRemaining = turnDuration
        beginCountdown()
    }

    private func beginCountdown() {
        phase = .countdown
        countdownValue = 3
        resetBall()
        flashMessage = nil
        clockAccumulator = 0
        Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                countdownValue = value
                Haptic.light()
                try? await Task.sleep(nanoseconds: 550_000_000)
            }
            countdownValue = 0
            phase = .playing
            flashMessage = "🏀 GO!"
            try? await Task.sleep(nanoseconds: 700_000_000)
            flashMessage = nil
        }
    }

    func returnToMenu() {
        phase = .menu
        isFlying = false
        isDragging = false
        flashMessage = nil
    }

    // MARK: - Input (drag ball with finger)

    func beginDrag(at point: CGPoint) {
        guard phase == .playing, !isFlying else { return }
        // Generous hit target so kids don't need pixel-perfect aim.
        let dx = point.x - ballX
        let dy = point.y - ballY
        guard (dx * dx + dy * dy) < pow(Self.ballRadius * 3.5, 2) else { return }
        isDragging = true
        dragStart = point
        dragCurrent = point
        // Ball rides the finger immediately.
        ballX = min(max(point.x, Self.ballRadius), 1 - Self.ballRadius)
        ballY = min(max(point.y, 0.12), 0.92)
        dragStart = CGPoint(x: ballX, y: ballY)
        updateGuide()
        Haptic.light()
    }

    func updateDrag(at point: CGPoint) {
        guard isDragging else { return }
        dragCurrent = point
        // Finger-follow drag (clamped to court).
        ballX = min(max(point.x, Self.ballRadius), 1 - Self.ballRadius)
        ballY = min(max(point.y, 0.12), 0.92)
        updateGuide()
    }

    func endDrag() {
        guard isDragging, phase == .playing, !isFlying else { return }
        isDragging = false
        let dx = dragCurrent.x - dragStart.x
        let dy = dragCurrent.y - dragStart.y
        // Require a mostly upward flick from where the drag started.
        guard dy < -0.025 else {
            guidePoints = []
            return
        }
        let (vx, vy) = launchVelocity(dx: dx, dy: dy)
        velocityX = vx
        velocityY = vy
        isFlying = true
        scoredThisFlight = false
        crossedAboveRim = false
        flightTime = 0
        guidePoints = []
        Haptic.medium()
    }

    private func launchVelocity(dx: CGFloat, dy: CGFloat) -> (CGFloat, CGFloat) {
        var vx = dx * swipeGain
        var vy = dy * swipeGain
        let speed = sqrt(vx * vx + vy * vy)
        let clamped = min(max(speed, minLaunchSpeed), maxLaunchSpeed)
        if speed > 0.0001 {
            let scale = clamped / speed
            vx *= scale
            vy *= scale
        } else {
            vx = 0
            vy = -minLaunchSpeed
        }
        return (vx, vy)
    }

    private func updateGuide() {
        let dx = dragCurrent.x - dragStart.x
        let dy = dragCurrent.y - dragStart.y
        let (vx, vy) = launchVelocity(dx: dx, dy: dy)
        var pts: [CGPoint] = []
        var x = ballX
        var y = ballY
        let svx = vx
        var svy = vy
        for _ in 0..<18 {
            svy += gravity * 0.045
            x += svx * 0.045
            y += svy * 0.045
            pts.append(CGPoint(x: x, y: y))
            if y > 1.05 || x < -0.1 || x > 1.1 { break }
        }
        guidePoints = pts
    }

    // MARK: - Physics

    func step(dt: CGFloat) {
        guard phase == .playing else { return }
        stepClock(dt: dt)
        guard isFlying else { return }

        flightTime += dt
        velocityY += gravity * dt
        let prevY = ballY
        ballX += velocityX * dt
        ballY += velocityY * dt

        // Court walls
        if ballX < Self.ballRadius {
            ballX = Self.ballRadius
            velocityX = abs(velocityX) * bounceRestitution
        }
        if ballX > 1 - Self.ballRadius {
            ballX = 1 - Self.ballRadius
            velocityX = -abs(velocityX) * bounceRestitution
        }

        collideWithRimAndBoard()
        detectScore(prevY: prevY)

        if rimHitFlash > 0 {
            rimHitFlash = max(0, rimHitFlash - dt * 3)
        }

        if ballY > 1.12 || flightTime > 3.2 {
            finishShot(scored: scoredThisFlight)
        }
    }

    private func stepClock(dt: CGFloat) {
        clockAccumulator += dt
        guard clockAccumulator >= 0.1 else { return }
        let tick = clockAccumulator
        clockAccumulator = 0

        switch mode {
        case .solo:
            soloTimeRemaining -= tick
            if soloTimeRemaining <= 0 {
                soloTimeRemaining = 0
                finishGame()
            }
        case .versus:
            if activePlayerIndex == 0 {
                p1TimeRemaining -= tick
                if p1TimeRemaining <= 0 {
                    p1TimeRemaining = 0
                    // Other player still has time?
                    if p2TimeRemaining > 0 && stats1.attempted + stats2.attempted >= 0 {
                        if p2TimeRemaining > 0 {
                            activePlayerIndex = 1
                            resetBall()
                            flashMessage = "\(player2.name)'s turn!"
                        } else {
                            finishGame()
                        }
                    } else {
                        finishGame()
                    }
                }
            } else {
                p2TimeRemaining -= tick
                if p2TimeRemaining <= 0 {
                    p2TimeRemaining = 0
                    finishGame()
                }
            }
        }
    }

    /// Solid rim (ellipse ring) + backboard behind the opening.
    private func collideWithRimAndBoard() {
        let hx = Self.hoopX
        let hy = Self.hoopY
        let rw = Self.rimHalfWidth
        let rh = Self.rimHalfHeight
        let r = Self.ballRadius

        // Backboard (thin rectangle behind/above rim)
        let boardLeft = hx - Self.backboardHalfWidth
        let boardRight = hx + Self.backboardHalfWidth
        let boardTop = hy - 0.10
        let boardBottom = hy - 0.01
        if ballX + r > boardLeft, ballX - r < boardRight,
           ballY + r > boardTop, ballY - r < boardBottom {
            // Push out vertically (board is a horizontal slab for front view)
            if ballY < (boardTop + boardBottom) * 0.5 {
                ballY = boardTop - r
                velocityY = -abs(velocityY) * bounceRestitution
            } else {
                ballY = boardBottom + r
                velocityY = abs(velocityY) * bounceRestitution
            }
            rimHitFlash = 1
            Haptic.light()
        }

        // Rim as ellipse ring: collide when near the ring path and not cleanly inside.
        let nx = (ballX - hx) / rw
        let ny = (ballY - hy) / rh
        let dist = sqrt(nx * nx + ny * ny)
        let inner = 0.72
        let outer = 1.25

        // Only bounce if ball is around the ring band (not deep center while scoring).
        if dist > inner && dist < outer, abs(ballY - hy) < rh * 3.2 {
            // Reflect outward from ellipse center
            var normalX = nx / max(rw, 0.001)
            var normalY = ny / max(rh, 0.001)
            let nLen = max(sqrt(normalX * normalX + normalY * normalY), 0.001)
            normalX /= nLen
            normalY /= nLen

            // Project velocity onto normal and bounce
            let vn = velocityX * normalX + velocityY * normalY
            if vn != 0 {
                velocityX = (velocityX - 2 * vn * normalX) * bounceRestitution
                velocityY = (velocityY - 2 * vn * normalY) * bounceRestitution
            } else {
                velocityX = -velocityX * bounceRestitution
                velocityY = -velocityY * bounceRestitution
            }

            // Nudge out of the ring band
            let target = min(max(dist, inner + 0.05), outer - 0.05)
            ballX = hx + nx / dist * target * rw
            ballY = hy + ny / dist * target * rh
            rimHitFlash = 1
            Haptic.light()
        }
    }

    private func detectScore(prevY: CGFloat) {
        // Clean score: ball crosses downward through the inner opening.
        let hy = Self.hoopY
        let dx = abs(ballX - Self.hoopX)
        let withinOpening = dx <= Self.rimHalfWidth * 0.78

        if ballY < hy - 0.02 {
            crossedAboveRim = true
        }
        let crossedDown = prevY <= hy && ballY > hy
        if crossedAboveRim, crossedDown, withinOpening, !scoredThisFlight {
            scoredThisFlight = true
            lastShotScored = true
        }
    }

    private func finishShot(scored: Bool) {
        isFlying = false
        var stats = activeStats
        stats.attempted += 1
        if scored {
            stats.made += 1
            stats.streak += 1
            stats.bestStreak = max(stats.bestStreak, stats.streak)
            let bonus = min(stats.streak, 3)
            stats.score += bonus
            flashMessage = stats.streak >= 3 ? "🔥 \(stats.streak) STREAK!  +\(bonus)" : "Swish!  +\(bonus)"
            celebrationLevel = stats.streak >= 5 ? 2 : 1
            Haptic.success()
        } else {
            stats.streak = 0
            flashMessage = ["Nice try! 🏀", "So close!", "Almost!"][Int.random(in: 0..<3)]
            Haptic.light()
        }
        activeStats = stats

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            flashMessage = nil
            celebrationLevel = 0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000)
            advanceAfterShot()
        }
    }

    private func advanceAfterShot() {
        resetBall()
        if mode == .versus {
            // Alternate turns while both still have clock left.
            if p1TimeRemaining <= 0 && p2TimeRemaining <= 0 {
                finishGame()
                return
            }
            activePlayerIndex = activePlayerIndex == 0 ? 1 : 0
            // Skip a player with no time left
            if activePlayerIndex == 0 && p1TimeRemaining <= 0 {
                activePlayerIndex = 1
            }
            if activePlayerIndex == 1 && p2TimeRemaining <= 0 {
                activePlayerIndex = 0
            }
            flashMessage = "\(activePlayer.name)'s turn!"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                if flashMessage?.contains("turn") == true { flashMessage = nil }
            }
        }
    }

    private func finishGame() {
        guard phase != .gameOver else { return }
        phase = .gameOver
        isFlying = false
        isDragging = false
        if mode == .solo {
            bestSoloScore = max(bestSoloScore, stats1.score)
        }
        Haptic.success()
    }

    private func resetBall() {
        ballX = 0.5
        ballY = 0.82
        velocityX = 0
        velocityY = 0
        isFlying = false
        isDragging = false
        guidePoints = []
        scoredThisFlight = false
        crossedAboveRim = false
        flightTime = 0
    }
}
