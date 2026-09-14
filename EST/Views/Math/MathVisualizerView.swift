import GameShell
import SwiftUI

/// A hands-on explanation of the four-trit structure behind EST.
struct MathVisualizerView: View {
    private enum Trait: Int, CaseIterable, Identifiable {
        case count, color, shape, fill

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .count: "count"
            case .color: "color"
            case .shape: "shape"
            case .fill: "fill"
            }
        }

        func valueName(for value: Int) -> String {
            switch self {
            case .count: String(value + 1)
            case .color: Card.Tint.allCases[value].name
            case .shape: Card.Symbol.allCases[value].name
            case .fill: Card.Fill.allCases[value].name
            }
        }

        /// Only the color coordinate changes the editor's accent. The other
        /// coordinates keep one stable surface while their card preview
        /// changes.
        func accent(for value: Int) -> Card.Tint {
            self == .color ? Card.Tint.allCases[value] : .blue
        }
    }

    /// This cap is a fixed, verified 20-card subset of the 81-card deck.
    /// Card.countSets(in:) is used again when the section renders.
    private static let pellegrinoCapIDs = [
        1, 3, 10, 13, 18, 21, 32, 34, 41, 44,
        49, 52, 54, 57, 59, 62, 64, 71, 72, 79
    ]

    @State private var editorTrits = [0, 0, 0, 0]
    @State private var forcePair: [Card] = {
        let trio = Card.randomValidSet()
        return Array(trio.prefix(2))
    }()
    @State private var gridSelection: [Int] = []

    private var editorCard: Card {
        Card(
            count: editorTrits[Trait.count.rawValue] + 1,
            tint: Card.Tint.allCases[editorTrits[Trait.color.rawValue]],
            symbol: Card.Symbol.allCases[editorTrits[Trait.shape.rawValue]],
            fill: Card.Fill.allCases[editorTrits[Trait.fill.rawValue]]
        )
    }

    private var completingCard: Card {
        Card.completing(forcePair[0], forcePair[1])
    }

    private var selectedGridCards: [Card] {
        gridSelection.map(Card.init(id:))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                intro

                sectionCard(
                    eyebrow: "01 / four coordinates",
                    title: "A card is four digits",
                    subtitle: "Tap a trait to change it. The card's base-3 ID changes with it."
                ) {
                    editorSection
                }

                sectionCard(
                    eyebrow: "02 / the set rule",
                    title: "Two cards determine the third",
                    subtitle: "Each trait sums to zero modulo three, leaving one possible third card."
                ) {
                    forceSection
                }

                sectionCard(
                    eyebrow: "03 / the whole space",
                    title: "All 81 cards",
                    subtitle: "Two trits on each axis create a 9 × 9 map of the deck. Tap two cells to reveal the card they determine."
                ) {
                    gridSection
                }

                sectionCard(
                    eyebrow: "04 / cap set",
                    title: "A 20-card cap",
                    subtitle: "These 20 cards contain no set. Add any 21st card and a set must appear."
                ) {
                    capSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Appearance.shared.gameBackground.ignoresSafeArea())
        .navigationTitle("The mathematics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cards are points. Sets are lines.")
                .font(.title2.bold())
            Text("EST is the affine space AG(4,3): four coordinates, three values each, and 81 points in all.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var editorSection: some View {
        VStack(spacing: 14) {
            CardView(card: editorCard, isSelected: true)
                .frame(width: 176, height: 176)
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.3), value: editorCard)

            Text("Base-3 ID \(editorCard.id) / 0 to 80")
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(Trait.allCases) { trait in
                    traitControl(for: trait)
                }
            }
        }
    }

    private func traitControl(for trait: Trait) -> some View {
        let value = editorTrits[trait.rawValue]
        let accent = trait.accent(for: value).color

        return Button {
            cycle(trait)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trait.label)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("Tap to change")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { state in
                        VStack(spacing: 4) {
                            traitStatePreview(
                                trait: trait,
                                value: state,
                                isSelected: state == value
                            )
                            Text(trait.valueName(for: state))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .foregroundStyle(state == value ? accent : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(state == value ? accent.opacity(0.14) : .clear)
                        }
                        .overlay {
                            if state == value {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(accent.opacity(0.55), lineWidth: 1)
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Text("Selected: \(trait.valueName(for: value))")
                    Text("Trit \(value)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2.monospaced())
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .glassButtonSurface(
                tint: accent,
                opacity: 0.12,
                cornerRadius: 14
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(trait.label), \(trait.valueName(for: value)), trit \(value)")
        .accessibilityHint("Cycles through the three values")
    }

    private func traitStatePreview(
        trait: Trait,
        value: Int,
        isSelected: Bool
    ) -> some View {
        CardView(
            card: Card(
                count: trait == .count ? value + 1 : 1,
                tint: trait == .color ? Card.Tint.allCases[value] : .blue,
                symbol: trait == .shape ? Card.Symbol.allCases[value] : .circle,
                fill: trait == .fill ? Card.Fill.allCases[value] : .solid
            ),
            isSelected: isSelected
        )
        .frame(width: 34, height: 34)
    }

    private var forceSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                explanatoryCard(forcePair[0], label: "first card")
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                explanatoryCard(forcePair[1], label: "second card")
                Image(systemName: "equal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                explanatoryCard(completingCard, label: "third card", isThird: true)
            }
            .frame(maxWidth: .infinity)

            Text(Card.isValidSet(forcePair[0], forcePair[1], completingCard) ? "Set" : "Not a set")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Card.Tint.blue.color)

            VStack(spacing: 8) {
                ForEach(Array(Card.audit(forcePair[0], forcePair[1], completingCard).enumerated()), id: \.element.id) { index, verdict in
                    HStack(spacing: 8) {
                        Text(verdict.label)
                            .font(.caption.weight(.semibold))
                            .frame(width: 48, alignment: .leading)

                        Text(outcomeName(for: verdict))
                            .font(.caption)

                        Spacer(minLength: 4)

                        Text("sum mod 3 = \(traitSum(at: index))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Card.Tint.blue.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassButtonSurface(
                        tint: verdict.isValid ? Card.Tint.blue.color : Card.Tint.red.color,
                        opacity: 0.10,
                        cornerRadius: 12
                    )
                }
            }

            Button {
                withAnimation(.spring(duration: 0.45)) {
                    let trio = Card.randomValidSet()
                    forcePair = Array(trio.prefix(2))
                }
            } label: {
                Label("Shuffle the pair", systemImage: "shuffle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.game(.secondary, tint: .second, size: .compact))
        }
    }

    private var gridSection: some View {
        VStack(spacing: 14) {
            grid

            HStack(spacing: 10) {
                Button {
                    showRandomLine()
                } label: {
                    Label("Show a set", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.game(.primary, tint: .second, size: .compact))

                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        gridSelection = []
                    }
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 20)
                }
                .buttonStyle(.game(.quiet, tint: .second, size: .icon))
                .accessibilityLabel("Clear selection")
            }

            Text(gridInstruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            FourDimensionalProjectionView()
        }
    }

    private var capSection: some View {
        let cards = Self.pellegrinoCapIDs.map(Card.init(id:))

        return VStack(spacing: 14) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5),
                spacing: 7
            ) {
                ForEach(cards) { card in
                    CardView(card: card)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                }
            }

            HStack {
                Label("20-card cap", systemImage: "square.grid.3x3.fill")
                Spacer()
                Text("\(Card.countSets(in: cards)) sets")
                    .foregroundStyle(Card.Tint.blue.color)
            }
            .font(.subheadline.weight(.semibold))

            Text("Pellegrino proved that 20 is the largest cap in AG(4,3).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Card.Tint.blue.color)
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .glassPanel(cornerRadius: 24)
    }

    private func explanatoryCard(_ card: Card, label: String, isThird: Bool = false) -> some View {
        VStack(spacing: 5) {
            CardView(card: card, isSelected: isThird)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isThird ? Card.Tint.yellow.color : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var grid: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let gap: CGFloat = 3
            let cellSide = (side - gap * 8) / 9

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<9, id: \.self) { column in
                                let card = Card(id: row * 9 + column)
                                gridCell(card, row: row, column: column, side: cellSide)
                            }
                        }
                    }
                }

                if selectedGridCards.count > 1 {
                    GridLineView(
                        points: selectedGridCards.map {
                            gridPoint(for: $0, cellSide: cellSide, gap: gap)
                        },
                        canvasSize: CGSize(width: side, height: side)
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func gridCell(_ card: Card, row: Int, column: Int, side: CGFloat) -> some View {
        let isSelected = gridSelection.contains(card.id)
        let isThird = gridSelection.count == 3 && gridSelection.last == card.id

        return Button {
            tapGrid(card)
        } label: {
            CardView(
                card: card,
                isSelected: isSelected,
                isDimmed: gridSelection.count == 3 && !isSelected
            )
            .overlay {
                if isThird {
                    CardChrome.shape(side: side)
                        .stroke(Card.Tint.yellow.color, lineWidth: 2)
                        .padding(1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .accessibilityLabel("\(card.accessibilityDescription), row \(row + 1), column \(column + 1)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double-tap to choose this card")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var gridInstruction: String {
        switch gridSelection.count {
        case 0: return "Tap any two cells. The third card is unique."
        case 1: return "One selected. Tap a second cell."
        default:
            let third = gridSelection[2]
            return "The third card is \(third). The line stays inside this map."
        }
    }

    private func cycle(_ trait: Trait) {
        withAnimation(.spring(duration: 0.25)) {
            editorTrits[trait.rawValue] = (editorTrits[trait.rawValue] + 1) % 3
        }
    }

    private func outcomeName(for verdict: Card.TraitVerdict) -> String {
        switch verdict.outcome {
        case .allSame: "same"
        case .allDifferent: "all different"
        case .twoAndOne: "two and one"
        }
    }

    private func traitSum(at index: Int) -> Int {
        let cards = [forcePair[0], forcePair[1], completingCard]
        return cards.reduce(0) { partial, card in
            partial + card.trits[index]
        } % 3
    }

    private func tapGrid(_ card: Card) {
        withAnimation(.spring(duration: 0.4)) {
            switch gridSelection.count {
            case 0:
                gridSelection = [card.id]
            case 1:
                guard gridSelection[0] != card.id else { return }
                let first = Card(id: gridSelection[0])
                let third = Card.completing(first, card)
                gridSelection = [first.id, card.id, third.id]
            default:
                gridSelection = [card.id]
            }
        }
    }

    private func showRandomLine() {
        withAnimation(.spring(duration: 0.6)) {
            gridSelection = Card.randomValidSet().map(\.id)
        }
    }

    private func gridPoint(for card: Card, cellSide: CGFloat, gap: CGFloat) -> CGPoint {
        let row = card.id / 9
        let column = card.id % 9
        return CGPoint(
            x: cellSide / 2 + CGFloat(column) * (cellSide + gap),
            y: cellSide / 2 + CGFloat(row) * (cellSide + gap)
        )
    }
}

/// Draws each selected-set segment as a straight line inside the 9 × 9 map.
private struct GridLineView: View {
    let points: [CGPoint]
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }

            let style = StrokeStyle(
                lineWidth: max(2, size.width * 0.012),
                lineCap: .round,
                lineJoin: .round
            )

            for pair in zip(points, points.dropFirst()) {
                var path = Path()
                path.move(to: pair.0)
                path.addLine(to: pair.1)
                context.stroke(
                    path,
                    with: .color(Card.Tint.blue.color.opacity(0.82)),
                    style: style
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        MathVisualizerView()
    }
}
