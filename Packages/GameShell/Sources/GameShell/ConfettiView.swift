import SwiftUI

/// End-of-game confetti: a game's own shapes drifting down behind the
/// wrap-up card. Pure Canvas, no particle framework. The view knows nothing
/// about cards: the caller passes the colors and a shape for each particle.
public struct ConfettiView: View {
    private struct Particle {
        public let x: CGFloat          // horizontal position, 0...1
        public let size: CGFloat
        public let speed: Double       // fall duration divisor
        public let phase: Double
        public let wobble: Double
        public let spin: Double
        public let color: Color
        public let shape: AnyShape
        public let opacity: Double
    }

    private let particles: [Particle]
    private let start = Date()

    /// `colors` defaults to the three identity accents. `shape` returns the
    /// silhouette for particle `index`; the default is a circle.
    public init(
        colors: [Color] = GameAccent.identity.map(\.color),
        shape: (Int) -> AnyShape = { _ in AnyShape(Circle()) }
    ) {
        particles = (0..<40).map { index in
            Particle(
                x: .random(in: 0...1),
                size: .random(in: 10...26),
                speed: .random(in: 0.08...0.18),
                phase: .random(in: 0...1),
                wobble: .random(in: 1.2...2.6),
                spin: .random(in: -2...2),
                color: colors.randomElement() ?? GameAccent.first.color,
                shape: shape(index),
                opacity: .random(in: 0.5...0.95)
            )
        }
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let progress = (t * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 2 * p.size) - p.size
                    let x = p.x * size.width + sin(t * p.wobble + p.phase * 10) * 18

                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size)
                    let path = p.shape.path(in: rect)

                    var layer = context
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(t * p.spin + p.phase * .pi * 2))
                    layer.opacity = p.opacity
                    layer.fill(path, with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
