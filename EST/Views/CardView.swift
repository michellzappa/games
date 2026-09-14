import Foundation
import SwiftUI

/// The one source for every card-shaped surface: the face, the back, a pile
/// layer, an empty slot. They all take their silhouette and their colors from
/// here, so a pile never shows a different corner radius or a different
/// surface color than the cards it holds.
enum CardChrome {
    static let cornerFraction: CGFloat = 0.12

    static func shape(side: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: side * cornerFraction, style: .continuous)
    }

    static var surface: Color { Appearance.shared.theme.cardSurface }
    static var border: Color { Appearance.shared.theme.cardBorder }
    static var slotBorder: Color { Appearance.shared.theme.cardSlotBorder }
}

/// A square card. Symbol placement by count: 1 centered, 2 side by side,
/// 3 on the vertices of an equilateral triangle centered in the card.
struct CardView: View {
    let card: Card
    var isSelected = false
    var isDimmed = false

    @State private var hoverLocation: CGPoint?
    @State private var isHovering = false
    @Environment(\.estReduceMotion) private var reduceMotion
    @Environment(\.estHighContrast) private var highContrast
    @Environment(\.estColorBlindAssist) private var colorBlindAssist
    @Environment(\.estCardRotation) private var cardRotation

    private static let referenceCardSide: CGFloat = 100
    private static let symbolGrowthRate = 2.0 / 3.0
    private static let symbolFraction: CGFloat = 0.23
    private static let gapFraction: CGFloat = 0.10

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let normalizedHoverX = min(
                max((hoverLocation?.x ?? side / 2) / max(side, 1), 0),
                1
            )
            let normalizedHoverY = min(
                max((hoverLocation?.y ?? side / 2) / max(side, 1), 0),
                1
            )
            let hoverTiltX = !reduceMotion && isHovering ? (0.5 - normalizedHoverY) * 7 : 0
            let hoverTiltY = !reduceMotion && isHovering ? (normalizedHoverX - 0.5) * 7 : 0

            ZStack {
                CardChrome.shape(side: side)
                    .fill(CardChrome.surface)
                    .shadow(
                        color: .black.opacity(isSelected ? 0.35 : isHovering ? 0.22 : 0.15),
                        radius: isSelected ? side * 0.06 : isHovering ? side * 0.08 : side * 0.03,
                        y: isSelected ? side * 0.02 : isHovering ? side * 0.04 : side * 0.02
                    )
                if isHovering {
                    RadialGradient(
                        colors: [
                            .white.opacity(0.30),
                            .white.opacity(0.08),
                            .clear
                        ],
                        center: UnitPoint(x: normalizedHoverX, y: normalizedHoverY),
                        startRadius: 0,
                        endRadius: side * 0.68
                    )
                    .clipShape(CardChrome.shape(side: side))
                }
                CardChrome.shape(side: side)
                    .strokeBorder(
                        isSelected
                            ? card.tint.color
                            : isHovering
                                ? card.tint.color.opacity(0.75)
                            : CardChrome.border,
                        lineWidth: isSelected ? 3 : isHovering ? 2 : highContrast ? 2 : 1
                    )

                symbols(side: side)
                    // Only the symbols turn. The card keeps its cell, so the
                    // grid a player is reading does not move under them.
                    .rotationEffect(cardRotation)
                    .animation(.spring(duration: 0.45), value: cardRotation)

                if colorBlindAssist {
                    Text(card.tint.accessibilityMarker)
                        .font(.system(size: max(8, side * 0.10), weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: max(16, side * 0.18), height: max(16, side * 0.18))
                        .background(.background.opacity(0.88), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.primary.opacity(highContrast ? 0.55 : 0.25), lineWidth: highContrast ? 1.5 : 1)
                        }
                        .padding(side * 0.08)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect((isSelected ? 1.06 : 1) * (isHovering ? 1.035 : 1))
            .rotation3DEffect(
                .degrees(hoverTiltX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(hoverTiltY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .opacity(isDimmed ? 0.35 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
        // A card's artwork is decorative by itself. Interactive containers
        // provide the full trait-based label and button action so VoiceOver
        // and Voice Control encounter one useful element per card.
        .accessibilityHidden(true)
        // Apple Pencil hover on supported iPads is delivered through the
        // continuous hover phase. The same path is harmless for a trackpad or
        // mouse, and touch selection remains handled by the board.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                if !isHovering {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.15)) {
                        isHovering = true
                    }
                }
            case .ended:
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    isHovering = false
                    hoverLocation = nil
                }
            }
        }
    }

    @ViewBuilder
    private func symbols(side: CGFloat) -> some View {
        // Keep symbols a little more legible on small cards and stop them
        // dominating larger iPad cards. Both symbol size and spacing use the
        // same nonlinear scale so the group keeps its proportions.
        let normalizedSide = max(side, 1) / Self.referenceCardSide
        let groupScale = CGFloat(
            Foundation.pow(Double(normalizedSide), Self.symbolGrowthRate)
        )
        let s = Self.referenceCardSide * Self.symbolFraction * groupScale
        let gap = Self.referenceCardSide * Self.gapFraction * groupScale
        ZStack {
            switch card.count {
            case 1:
                symbol(s)
            case 2:
                let dx = (s + gap) / 2
                symbol(s).offset(x: -dx)
                symbol(s).offset(x: dx)
            default:
                // Center the triangle's visible bounds, not just its
                // centroid: the top vertex reaches farther from the center
                // than the bottom pair. The correction keeps the bottom
                // pair exactly `gap` apart.
                let r = (s + gap) / sqrt(3.0)
                let dx = r * sin(.pi / 3)
                let verticalCorrection = r / 4
                symbol(s).offset(y: -r + verticalCorrection)
                symbol(s).offset(x: -dx, y: r / 2 + verticalCorrection)
                symbol(s).offset(x: dx, y: r / 2 + verticalCorrection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func symbol(_ side: CGFloat) -> some View {
        SymbolView(symbol: card.symbol, fill: card.fill, tint: card.tint)
            .frame(width: side, height: side)
    }
}

struct SymbolView: View {
    let symbol: Card.Symbol
    let fill: Card.Fill
    let tint: Card.Tint

    /// Optical size correction. In the same bounding square the areas are
    /// square 0.99, circle 0.785, triangle 0.433 (in units of side^2), so
    /// the square reads too big and the triangle too small. Halfway
    /// correction, circle as reference.
    private var opticalScale: CGFloat {
        switch symbol {
        case .circle: 1
        case .square: 0.95
        case .triangle: 1.06
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(1.5, proxy.size.width * 0.09)
            let shape = ElementaryShape(symbol: symbol)
            // Each fill has its own silhouette logic so they never blur
            // together: solid is all fill and no rim, translucent is a pale
            // wash (or pinstripes, per settings) under a strong rim, outline
            // is the rim alone.
            ZStack {
                switch fill {
                case .solid:
                    shape.fill(tint.gradient)
                case .outline:
                    shape.stroke(tint.color, lineWidth: lineWidth)
                case .translucent:
                    if Appearance.shared.fillStyle == .pinstriped {
                        DiagonalStripes(color: tint.color)
                            .clipShape(shape)
                    } else {
                        shape.fill(tint.color.opacity(0.24))
                    }
                    shape.stroke(tint.color, lineWidth: lineWidth)
                }
            }
            .padding(lineWidth / 2)
            .scaleEffect(opticalScale)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// How the cards face. A game screen sets this on its board; every `CardView`
/// under it turns its symbols by that angle. Only the symbols turn, so the
/// grid keeps the same cards in the same cells.
private struct ESTCardRotationKey: EnvironmentKey {
    static let defaultValue = Angle.zero
}

extension EnvironmentValues {
    var estCardRotation: Angle {
        get { self[ESTCardRotationKey.self] }
        set { self[ESTCardRotationKey.self] = newValue }
    }
}

extension ConfettiView {
    /// Confetti in EST's own symbols and tints.
    static func cards(tints: [Card.Tint] = Card.Tint.allCases) -> ConfettiView {
        ConfettiView(colors: tints.map(\.color)) { _ in
            AnyShape(ElementaryShape(symbol: Card.Symbol.allCases.randomElement()!))
        }
    }
}

struct ElementaryShape: Shape {
    let symbol: Card.Symbol

    func path(in rect: CGRect) -> Path {
        switch symbol {
        case .circle:
            return Path(ellipseIn: rect)
        case .square:
            return Path(roundedRect: rect, cornerRadius: rect.width * 0.1)
        case .triangle:
            // Equilateral: height = width * sqrt(3)/2, vertically centered
            // in the square frame.
            let height = rect.width * sqrt(3) / 2
            let top = rect.midY - height / 2
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: top))
            path.addLine(to: CGPoint(x: rect.maxX, y: top + height))
            path.addLine(to: CGPoint(x: rect.minX, y: top + height))
            path.closeSubpath()
            return path
        }
    }
}

/// The pinstriped alternative to the shaded fill: 45-degree stripes with
/// round caps, clipped to the symbol.
struct DiagonalStripes: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step = max(4, size.width / 5.5)
            let lineWidth = step * 0.42
            var d = -size.height + step / 2
            while d < size.width {
                var line = Path()
                line.move(to: CGPoint(x: d, y: size.height))
                line.addLine(to: CGPoint(x: d + size.height, y: 0))
                context.stroke(
                    line,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                d += step
            }
        }
    }
}

/// Horizontal shake used for mismatched selections.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}

#Preview {
    VStack {
        HStack {
            CardView(card: Card(count: 3, tint: .red, symbol: .triangle, fill: .translucent))
            CardView(card: Card(count: 2, tint: .blue, symbol: .circle, fill: .outline), isSelected: true)
            CardView(card: Card(count: 1, tint: .yellow, symbol: .square, fill: .solid))
        }
        HStack {
            CardView(card: Card(count: 3, tint: .blue, symbol: .square, fill: .solid))
            CardView(card: Card(count: 3, tint: .yellow, symbol: .circle, fill: .translucent))
            CardView(card: Card(count: 2, tint: .red, symbol: .triangle, fill: .solid))
        }
    }
    .padding()
}
