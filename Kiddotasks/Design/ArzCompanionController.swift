import Foundation
import Observation

/// App-level events Arz can react to. Keep free of business logic —
/// UI layers emit events; the controller maps them to expressions.
enum ArzCompanionEvent: String, Sendable {
    case taskCompleted
    case multipleTasksCompleted
    case achievementUnlocked
    case aiProcessing
    case taskOverdue
    case error
    case userTap
    case dashboardOpened
    case kidsStationOpened
}

/// State-driven animation controller for Arz.
/// Pages call `Arz.play("happy")` or `handle(.taskCompleted)`;
/// temporary expressions automatically return to idle.
@Observable
@MainActor
final class ArzCompanionController {
    static let shared = ArzCompanionController()

    private(set) var expression: ArzExpression = .idle
    private(set) var isBlinking = false
    private(set) var playToken = 0

    private let cooldown: TimeInterval = 0.45
    private var lastAcceptedPlayAt: Date = .distantPast
    private var activePriority: Int = 0
    private var returnTask: Task<Void, Never>?

    private init() {}

    func play(_ name: String) {
        guard let expression = ArzExpression.from(playName: name) else { return }
        play(expression)
    }

    func play(_ next: ArzExpression, force: Bool = false) {
        let now = Date()
        let inCooldown = now.timeIntervalSince(lastAcceptedPlayAt) < cooldown

        if !force {
            if inCooldown && next.priority < activePriority { return }
            if next == expression && !next.isSticky {
                scheduleReturn(after: next.holdDuration)
                return
            }
            if inCooldown && next.priority <= activePriority && next != expression {
                return
            }
        }

        lastAcceptedPlayAt = now
        activePriority = next.priority
        expression = next
        playToken &+= 1
        isBlinking = false

        returnTask?.cancel()
        if next != .idle {
            scheduleReturn(after: next.holdDuration)
        }
    }

    func handle(_ event: ArzCompanionEvent) {
        switch event {
        case .taskCompleted:
            play(.happy)
        case .multipleTasksCompleted, .achievementUnlocked, .kidsStationOpened:
            play(.excited)
        case .aiProcessing:
            play(.thinking)
        case .taskOverdue:
            play(.encouraging)
        case .error:
            play(.sad)
        case .userTap:
            // Tap only shows the phrase bubble — keep the resting face stable.
            break
        case .dashboardOpened:
            play(.happy)
        }
    }

    func returnToIdle() {
        returnTask?.cancel()
        isBlinking = false
        activePriority = 0
        lastAcceptedPlayAt = .distantPast
        if expression != .idle {
            expression = .idle
            playToken &+= 1
        }
    }

    func setBlinking(_ blinking: Bool) {
        guard expression == .idle || expression == .happy else { return }
        guard isBlinking != blinking else { return }
        isBlinking = blinking
        playToken &+= 1
    }

    private func scheduleReturn(after delay: TimeInterval) {
        returnTask?.cancel()
        returnTask = Task { [weak self] in
            let nanos = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled, let self else { return }
            if self.expression != .idle {
                self.expression = .idle
                self.activePriority = 0
                self.isBlinking = false
                self.playToken &+= 1
            }
        }
    }
}

/// Facade: `Arz.play("happy")`, `Arz.handle(.taskCompleted)`.
@MainActor
enum Arz {
    static func play(_ state: String) {
        ArzCompanionController.shared.play(state)
    }

    static func play(_ expression: ArzExpression) {
        ArzCompanionController.shared.play(expression)
    }

    static func handle(_ event: ArzCompanionEvent) {
        ArzCompanionController.shared.handle(event)
    }

    static func returnToIdle() {
        ArzCompanionController.shared.returnToIdle()
    }
}
