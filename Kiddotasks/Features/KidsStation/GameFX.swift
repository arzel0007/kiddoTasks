import AudioToolbox
import SwiftUI

// MARK: - Sound hooks (no external assets)

enum GameSounds {
    static func tap() { AudioServicesPlaySystemSound(1104) }
    static func place() { AudioServicesPlaySystemSound(1103) }
    static func win() { AudioServicesPlaySystemSound(1025) }
    static func draw() { AudioServicesPlaySystemSound(1057) }
    static func flip() { AudioServicesPlaySystemSound(1104) }
    static func match() { AudioServicesPlaySystemSound(1306) }
    static func miss() { AudioServicesPlaySystemSound(1053) }
    static func restart() { AudioServicesPlaySystemSound(1105) }
}

// MARK: - Reduced motion

extension EnvironmentValues {
    var kiddoReduceMotion: Bool {
        accessibilityReduceMotion
    }
}

// MARK: - Particle / confetti

struct GameParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var color: Color
    var rotation: Double
    var life: Double = 1
}

/// Lightweight canvas confetti — burst once, self-cleans.
struct ConfettiOverlay: View {
    var trigger: Int
    var particleCount: Int = 42

    @State private var particles: [GameParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let palette: [Color] = [
        Color(hex: "#3978A8"),
        Color(hex: "#3F8B70"),
        Color(hex: "#D59A3A"),
        Color(hex: "#D97868"),
        Color(hex: "#6F9FBD"),
        Color(hex: "#E8B84A"),
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for p in particles {
                    let rect = CGRect(
                        x: p.x - p.size / 2,
                        y: p.y - p.size / 2,
                        width: p.size,
                        height: p.size * 0.65
                    )
                    var ctx = context
                    ctx.translateBy(x: p.x, y: p.y)
                    ctx.rotate(by: .radians(p.rotation))
                    ctx.translateBy(x: -p.x, y: -p.y)
                    ctx.opacity = p.life
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(p.color)
                    )
                }
            }
            .allowsHitTesting(false)
            .onAppear { lastSize = geo.size }
            .onChange(of: geo.size) { _, s in lastSize = s }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0, !reduceMotion else { return }
                fire(size: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    @State private var lastSize: CGSize = .zero

    private func fire(size: CGSize) {
        let canvasSize = size
        guard canvasSize.width > 1, canvasSize.height > 1 else { return }

        var next: [GameParticle] = []
        for _ in 0..<particleCount {
            next.append(
                GameParticle(
                    x: canvasSize.width * CGFloat.random(in: 0.2...0.8),
                    y: canvasSize.height * 0.35,
                    vx: CGFloat.random(in: -4...4),
                    vy: CGFloat.random(in: -7 ... -3),
                    size: CGFloat.random(in: 5...10),
                    color: Self.palette.randomElement() ?? .blue,
                    rotation: Double.random(in: 0...(Double.pi * 2))
                )
            )
        }
        particles = next

        let start = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(start)
            Task { @MainActor in
                if elapsed > 1.35 {
                    t.invalidate()
                    particles = []
                    return
                }
                for i in particles.indices {
                    particles[i].vy += 0.18
                    particles[i].x += particles[i].vx
                    particles[i].y += particles[i].vy
                    particles[i].rotation += 0.15
                    particles[i].life = max(0, 1 - elapsed / 1.35)
                }
            }
        }
        TimerHolder.shared.retain(timer, key: "confetti-\(trigger)")
    }
}

/// Keeps short-lived timers alive until invalidate.
@MainActor
final class TimerHolder {
    static let shared = TimerHolder()
    private var storage: [String: Timer] = [:]

    func retain(_ timer: Timer, key: String) {
        storage[key]?.invalidate()
        storage[key] = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.storage[key]?.invalidate()
            self?.storage[key] = nil
        }
    }
}

// MARK: - Sparkle burst (small)

struct SparkleBurst: View {
    var active: Bool
    var color: Color = Color(hex: "#D59A3A")

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .offset(
                        x: animate ? cos(Double(i) / 6 * .pi * 2) * 22 : 0,
                        y: animate ? sin(Double(i) / 6 * .pi * 2) * 22 : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 1.4 : 0.3)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: active) { _, on in
            guard on else {
                animate = false
                return
            }
            withAnimation(.easeOut(duration: 0.45)) { animate = true }
        }
    }
}

// MARK: - Floating score pop ("⭐ +10")

struct ScorePopView: View {
    var text: String
    var trigger: Int

    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: "#8a6420"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(KiddoTasksDesignTokens.Colors.rewardLight))
            .opacity(visible ? 0 : 1)
            .offset(y: visible ? -36 : 0)
            .scaleEffect(visible ? 0.85 : 0.7)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, value in
                guard value > 0, !reduceMotion else { return }
                visible = false
                withAnimation(.easeOut(duration: 0.7).delay(0.02)) {
                    visible = true
                }
            }
    }
}

// MARK: - Draw-on X / O shapes

struct XMarkShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Two strokes sequential: 0–0.5 first diagonal, 0.5–1 second
        var path = Path()
        let inset = rect.width * 0.22
        let a = CGPoint(x: rect.minX + inset, y: rect.minY + inset)
        let b = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let c = CGPoint(x: rect.maxX - inset, y: rect.minY + inset)
        let d = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)

        let p1 = min(progress * 2, 1)
        path.move(to: a)
        path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * p1, y: a.y + (b.y - a.y) * p1))

        if progress > 0.5 {
            let p2 = (progress - 0.5) * 2
            path.move(to: c)
            path.addLine(to: CGPoint(x: c.x + (d.x - c.x) * p2, y: c.y + (d.y - c.y) * p2))
        }
        return path
    }
}

struct OMarkShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.22
        let circle = rect.insetBy(dx: inset, dy: inset)
        // Start at top, draw clockwise
        var path = Path()
        path.addArc(
            center: CGPoint(x: circle.midX, y: circle.midY),
            radius: circle.width / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * Double(min(max(progress, 0), 1))),
            clockwise: false
        )
        return path
    }
}
