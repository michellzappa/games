import GameShell
import SwiftUI

/// Where the deck and played-card piles sit on screen, measured in the "game"
/// coordinate space. The board uses these frames to animate cards to and from
/// the piles.
struct PileFrames: Equatable {
    var draw: CGRect?
    var done: CGRect?
    var cardBoxes: [String: CGRect]

    init(
        draw: CGRect? = nil,
        done: CGRect? = nil,
        cardBoxes: [String: CGRect] = [:]
    ) {
        self.draw = draw
        self.done = done
        self.cardBoxes = cardBoxes
    }
}

struct PileFramesKey: PreferenceKey {
    static var defaultValue = PileFrames()

    static func reduce(value: inout PileFrames, nextValue: () -> PileFrames) {
        let next = nextValue()
        if let draw = next.draw { value.draw = draw }
        if let done = next.done { value.done = done }
        value.cardBoxes.merge(next.cardBoxes) { _, new in new }
    }
}

/// Lines the progress bar up with the middle of the pile cards rather than the
/// middle of the whole pile column. The counts and labels below the cards would
/// otherwise pull the bar down.
private enum PileCardCenter: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[VerticalAlignment.center]
    }
}

extension VerticalAlignment {
    static let pileCardCenter = VerticalAlignment(PileCardCenter.self)
}

enum PileFrameTarget: Equatable {
    case draw
    case done
}

/// Bottom bar: the remaining deck on the left, the done pile on the right.
/// Both drawn as physical stacks, with counts.
struct PilesView: View {
    let deckCount: Int
    let doneCount: Int
    let doneTop: Card?
    var setsOnTable: Int?
    var totalCards = 81

    init(engine: GameEngine) {
        deckCount = engine.deck.count
        doneCount = engine.done.count
        doneTop = engine.done.last
        setsOnTable = Card.countSets(in: engine.table)
        totalCards = engine.totalCards
    }

    init(
        deckCount: Int,
        doneCount: Int,
        doneTop: Card?,
        setsOnTable: Int? = nil,
        totalCards: Int = 81
    ) {
        self.deckCount = deckCount
        self.doneCount = doneCount
        self.doneTop = doneTop
        self.setsOnTable = setsOnTable
        self.totalCards = totalCards
    }

    var body: some View {
        HStack(alignment: .pileCardCenter, spacing: 14) {
            PileStack(
                label: "deck",
                count: deckCount,
                topFace: nil,
                frameTarget: .draw
            )
            DeckProgressBar(
                deckCount: deckCount,
                doneCount: doneCount,
                setsOnTable: setsOnTable,
                totalCards: totalCards
            )
            .frame(maxWidth: .infinity)
            PileStack(
                label: "played",
                count: doneCount,
                topFace: doneTop,
                frameTarget: .done
            )
        }
    }
}

/// A player's collected cards. Unlike the shared draw/played piles, this is
/// personal progress and belongs beside that player's SET button in a party.
struct PlayerDeckView: View {
    let cardCount: Int
    var frameID: String? = nil
    private let side = GameButtonStyle.Size.large.height

    var body: some View {
        ZStack {
            CardChrome.shape(side: side)
                .strokeBorder(
                    CardChrome.slotBorder,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
                .frame(width: side, height: side)

            VStack(spacing: 0) {
                Text("\(cardCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                Text("CARDS")
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(width: side, height: side)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: PileFramesKey.self,
                    value: PileFrames(
                        cardBoxes: frameID.map {
                            [$0: geo.frame(in: .named("game"))]
                        } ?? [:]
                    )
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cardCount) cards collected")
    }
}

/// The progress bar shows cards moving from the deck to the table and then to
/// the played pile.
struct DeckProgressBar: View {
    let deckCount: Int
    let doneCount: Int
    var setsOnTable: Int?
    var totalCards = 81

    private static let barHeight: CGFloat = 10

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let doneFraction = CGFloat(doneCount) / CGFloat(totalCards)
                let inPlayFraction = CGFloat(totalCards - deckCount) / CGFloat(totalCards)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: max(deckCount < totalCards ? 10 : 0, width * inPlayFraction))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Card.Tint.red.color,
                                    Card.Tint.blue.color,
                                    Card.Tint.yellow.color,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: doneCount > 0 ? max(10, width * doneFraction) : 0)
                        }
                }
            }
            .frame(height: Self.barHeight)
            .animation(.spring(duration: 0.5), value: doneCount)
            .animation(.spring(duration: 0.5), value: deckCount)

            VStack(spacing: 1) {
                Text("\(doneCount / 3) of \(totalCards / 3)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let setsOnTable {
                    Text("\(setsOnTable) set\(setsOnTable == 1 ? "" : "s") visible")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        // The bar is the first thing in this column, so its middle sits half
        // a bar height down.
        .alignmentGuide(.pileCardCenter) { _ in Self.barHeight / 2 }
    }
}

/// A small stack of cards with a count badge. `topFace == nil` renders card
/// backs (the draw pile); otherwise the last collected card shows on top.
struct PileStack: View {
    static let cardSide: CGFloat = 52

    let label: String
    let count: Int
    let topFace: Card?
    var showsMetadata = true
    var frameTarget: PileFrameTarget? = nil

    private var side: CGFloat { Self.cardSide }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if count == 0 {
                    CardChrome.shape(side: side)
                        .strokeBorder(
                            CardChrome.slotBorder,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                        .frame(width: side, height: side)
                } else {
                    ForEach(0..<min(count, 5), id: \.self) { layer in
                        stackLayer(layer: layer)
                            .offset(
                                x: CGFloat(layer) * -1.5,
                                y: CGFloat(layer) * -1.5
                            )
                    }
                }
            }
            .frame(width: side + 8, height: side + 8)
            .animation(.spring(duration: 0.35), value: count)
            .background {
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("game"))
                    Color.clear.preference(
                        key: PileFramesKey.self,
                        value: PileFrames(
                            draw: frameTarget == .draw ? frame : nil,
                            done: frameTarget == .done ? frame : nil
                        )
                    )
                }
            }

            if showsMetadata {
                Text("\(count)")
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        // The card box leads this column, and it carries 4 points of padding
        // on each side, so its middle sits at half that box.
        .alignmentGuide(.pileCardCenter) { _ in (side + 8) / 2 }
    }

    @ViewBuilder
    private func stackLayer(layer: Int) -> some View {
        let isTop = layer == min(count, 5) - 1
        if isTop, let topFace {
            CardView(card: topFace)
                .frame(width: side, height: side)
        } else if isTop {
            CardBackView()
                .frame(width: side, height: side)
        } else {
            CardChrome.shape(side: side)
                .fill(CardChrome.surface)
                .overlay(
                    CardChrome.shape(side: side)
                        .strokeBorder(CardChrome.border, lineWidth: 1)
                )
                .frame(width: side, height: side)
        }
    }
}

/// Card back: the same tile as a card face, shaded, with the three elementary
/// shapes as a motif. It builds on `CardChrome`, so a theme or an appearance
/// change moves the back and the face together.
struct CardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack {
                CardChrome.shape(side: side)
                    .fill(CardChrome.surface)
                CardChrome.shape(side: side)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.14),
                                Color.primary.opacity(0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                HStack(spacing: side * 0.06) {
                    SymbolView(symbol: .circle, fill: .outline, tint: .red)
                    SymbolView(symbol: .square, fill: .outline, tint: .blue)
                    SymbolView(symbol: .triangle, fill: .outline, tint: .yellow)
                }
                .frame(width: side * 0.62)
                CardChrome.shape(side: side)
                    .strokeBorder(CardChrome.border, lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
