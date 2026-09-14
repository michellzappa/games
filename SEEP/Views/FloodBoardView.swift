import GameShell
import GridKit
import SwiftUI

/// The board as colored tiles. The corner region is outlined so the player
/// sees what the next move grows. Taps are reported by color, because the
/// only move in SEEP is "become this color"; tapping a tile means "become
/// that tile's color", which is the same move with a bigger target.
struct FloodBoardView: View {
    let board: FloodBoard
    var highlightRegion = true
    var onTapColor: ((Int) -> Void)?

    @Environment(\.estReduceMotion) private var reduceMotion
    @Environment(\.estColorBlindAssist) private var colorBlindAssist

    var body: some View {
        let region = Set(board.region())
        return GridBoardView(columns: board.size, rows: board.size, gap: 2, onTap: { position in
            onTapColor?(board.color(row: position.row, column: position.column))
        }) { (position: GridBoardView<FloodTile>.Position, side: CGFloat) -> FloodTile in
            let index = position.row * board.size + position.column
            return FloodTile(
                color: board.cells[index],
                side: side,
                inRegion: highlightRegion && region.contains(index),
                showSymbol: colorBlindAssist && side >= 14,
                reduceMotion: reduceMotion,
                label: "\(FloodPalette.name(board.cells[index])), row \(position.row + 1), column \(position.column + 1)"
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// One cell. A separate view keeps the board's cell closure small enough
/// for the type checker and animates its own color change.
struct FloodTile: View {
    let color: Int
    let side: CGFloat
    let inRegion: Bool
    let showSymbol: Bool
    let reduceMotion: Bool
    let label: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.18, style: .continuous)
                .fill(FloodPalette.color(color))
            if inRegion {
                RoundedRectangle(cornerRadius: side * 0.18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: max(1, side * 0.08))
            }
            if showSymbol {
                Image(systemName: FloodPalette.symbols[color])
                    .font(.system(size: side * 0.42))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: color)
        .accessibilityLabel(label)
    }
}

/// One swatch button per color. The corner's own color is disabled because
/// it is not a move.
struct FloodColorBar: View {
    let board: FloodBoard
    var hintColor: Int?
    var enabled = true
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<board.colorCount, id: \.self) { color in
                Button {
                    onSelect(color)
                } label: {
                    Circle()
                        .fill(FloodPalette.color(color))
                        .overlay {
                            if hintColor == color {
                                Circle().strokeBorder(Color.primary, lineWidth: 3)
                            }
                        }
                        .padding(6)
                }
                .buttonStyle(.game(.quiet, size: .icon))
                .disabled(!enabled || color == board.floodColor)
                .opacity(color == board.floodColor ? 0.35 : 1)
                .accessibilityLabel("Flood \(FloodPalette.name(color))")
            }
        }
    }
}
