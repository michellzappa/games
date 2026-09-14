import GameShell
import SwiftUI

/// A concrete slice of the four-dimensional card space. Holding count and
/// color still leaves a 3 × 3 plane of shape and fill values. The nine slices
/// are selectable as a count × color map, so movement through the fourth
/// dimension is visible rather than hidden behind numeric controls.
struct FourDimensionalProjectionView: View {
    @State private var fixedCountTrit = 0
    @State private var fixedColorTrit = 0
    @State private var selection: [Int] = []

    private var sliceCards: [Card] {
        (0..<9).map { index in
            Card(
                count: fixedCountTrit + 1,
                tint: Card.Tint.allCases[fixedColorTrit],
                symbol: Card.Symbol.allCases[index / 3],
                fill: Card.Fill.allCases[index % 3]
            )
        }
    }

    private var selectedCards: [Card] {
        selection.map(Card.init(id:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The 4D space, in slices")
                    .font(.headline)
                Text("Hold count and color still. The other two form a 3 × 3 plane. Choose from all nine planes below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            slicePicker

            Text("This slice: \(fixedCountTrit + 1) symbols · \(Card.Tint.allCases[fixedColorTrit].name)")
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(Card.Tint.blue.color)

            Text("Plane \(fixedCountTrit * 3 + fixedColorTrit + 1) of 9. Each plane contains nine shape × fill combinations.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Shape ↓")
                Spacer()
                Text("Fill →")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)

            sliceGrid

            Text("Tap two cards. The straight line shows where the third lands in this plane.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if selectedCards.count == 3 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card \(selectedCards[2].id) is forced. Nine slices of nine cards make 81.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Card.Tint.blue.color)
                    Text("Count and color stay fixed here. Shape and fill supply the missing values.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.35), value: selection)
        .animation(.spring(duration: 0.25), value: fixedCountTrit)
        .animation(.spring(duration: 0.25), value: fixedColorTrit)
    }

    private var slicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a slice: count ↓ × color →")
                .font(.caption.weight(.semibold))

            HStack(spacing: 5) {
                Text(" ")
                    .frame(width: 34)
                ForEach(Card.Tint.allCases, id: \.self) { tint in
                    Text(tint.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint.color)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<3, id: \.self) { count in
                HStack(spacing: 5) {
                    Text(String(count + 1))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .frame(width: 34)

                    ForEach(Card.Tint.allCases, id: \.self) { tint in
                        sliceButton(count: count, tint: tint)
                    }
                }
            }
        }
    }

    private func sliceButton(count: Int, tint: Card.Tint) -> some View {
        let isSelected = fixedCountTrit == count && fixedColorTrit == tint.rawValue

        return Button {
            withAnimation(.spring(duration: 0.25)) {
                fixedCountTrit = count
                fixedColorTrit = tint.rawValue
                selection = []
            }
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(0...count, id: \.self) { _ in
                        Circle()
                            .fill(tint.gradient)
                            .frame(width: 7, height: 7)
                    }
                }
                Text("\(count + 1)")
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .glassButtonSurface(
                tint: tint.color,
                opacity: isSelected ? 0.24 : 0.08,
                cornerRadius: 10
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.color, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count + 1) symbols, \(tint.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sliceGrid: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let gap: CGFloat = 5
            let cellSide = (side - gap * 2) / 3

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<3, id: \.self) { column in
                                let index = row * 3 + column
                                sliceCell(sliceCards[index], index: index, side: cellSide)
                            }
                        }
                    }
                }

                if selectedCards.count > 1 {
                    SliceLineView(
                        points: selectedCards.map {
                            point(for: $0, side: cellSide, gap: gap)
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

    private func sliceCell(_ card: Card, index: Int, side: CGFloat) -> some View {
        let isSelected = selection.contains(card.id)
        let isThird = selection.count == 3 && selection.last == card.id

        return Button {
            tap(card)
        } label: {
            CardView(
                card: card,
                isSelected: isSelected,
                isDimmed: selection.count == 3 && !isSelected
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
        .accessibilityLabel(
            "\(card.accessibilityDescription), shape row \(index / 3 + 1), fill column \(index % 3 + 1)"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double-tap to choose this card")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var instruction: String {
        switch selection.count {
        case 0: return "Tap two cards. The third is where the two straight segments meet."
        case 1: return "One selected. Tap a second card in this slice."
        default: return "The third card is highlighted in this plane."
        }
    }

    private func tap(_ card: Card) {
        withAnimation(.spring(duration: 0.4)) {
            switch selection.count {
            case 0:
                selection = [card.id]
            case 1:
                guard selection[0] != card.id else { return }
                let first = Card(id: selection[0])
                selection = [first.id, card.id, Card.completing(first, card).id]
            default:
                selection = [card.id]
            }
        }
    }

    private func point(for card: Card, side: CGFloat, gap: CGFloat) -> CGPoint {
        let index = card.symbol.rawValue * 3 + card.fill.rawValue
        return CGPoint(
            x: side / 2 + CGFloat(index % 3) * (side + gap),
            y: side / 2 + CGFloat(index / 3) * (side + gap)
        )
    }
}

/// Draws the selected set as straight segments clipped to the current slice.
private struct SliceLineView: View {
    let points: [CGPoint]
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }

            let style = StrokeStyle(
                lineWidth: max(2, canvasSize.width * 0.016),
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
    FourDimensionalProjectionView()
        .padding()
}
