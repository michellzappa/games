import GameShell
import GridKit
import SwiftUI

/// Number colors, from the theme so a theme change recolors the board.
enum MinePalette {
    static func number(_ n: Int) -> Color {
        switch n {
        case 1: GameAccent.second.color
        case 2: Appearance.shared.successColor
        case 3: GameAccent.first.color
        case 4: Appearance.shared.theme.fourthPlayerColor
        case 5: GameAccent.third.color
        case 6: GameAccent.second.highlight
        case 7: GameAccent.first.highlight
        default: Color.primary
        }
    }
}

/// The board. Closed cells are raised tiles in the theme surface; open
/// cells are flat. Tap and long press are reported by index.
struct MineBoardView: View {
    let board: MineBoard
    var exploded: Int?
    var hintCell: Int?
    var showsAllMines = false
    var onTap: ((Int) -> Void)?
    var onLongPress: ((Int) -> Void)?

    @Environment(\.estReduceMotion) private var reduceMotion
    @Environment(\.estHighContrast) private var highContrast

    var body: some View {
        GridBoardView(
            columns: board.width,
            rows: board.height,
            gap: 1.5,
            onTap: { onTap?(board.index(row: $0.row, column: $0.column)) },
            onLongPress: { onLongPress?(board.index(row: $0.row, column: $0.column)) }
        ) { (position: GridBoardView<MineTile>.Position, side: CGFloat) -> MineTile in
            let index = board.index(row: position.row, column: position.column)
            let cell = board.cells[index]
            return MineTile(
                cell: cell,
                side: side,
                isExploded: exploded == index,
                isHinted: hintCell == index,
                highContrast: highContrast,
                reduceMotion: reduceMotion,
                label: label(cell, position)
            )
        }
        .aspectRatio(CGFloat(board.width) / CGFloat(board.height), contentMode: .fit)
    }

    private func label(_ cell: MineBoard.Cell, _ position: GridBoardView<MineTile>.Position) -> String {
        let place = "row \(position.row + 1), column \(position.column + 1)"
        if cell.isFlagged { return "flag, \(place)" }
        if !cell.isOpen { return "closed, \(place)" }
        if cell.isMine { return "mine, \(place)" }
        return cell.adjacent == 0 ? "open, \(place)" : "\(cell.adjacent), \(place)"
    }
}

struct MineTile: View {
    let cell: MineBoard.Cell
    let side: CGFloat
    let isExploded: Bool
    let isHinted: Bool
    let highContrast: Bool
    let reduceMotion: Bool
    let label: String

    var body: some View {
        ZStack {
            if cell.isOpen {
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .fill(isExploded ? Appearance.shared.errorColor.opacity(0.85) : Color.primary.opacity(highContrast ? 0.12 : 0.06))
                if cell.isMine {
                    Image(systemName: "circle.fill")
                        .font(.system(size: side * 0.42))
                        .foregroundStyle(isExploded ? Color.white : Color.primary.opacity(0.8))
                } else if cell.adjacent > 0 {
                    Text("\(cell.adjacent)")
                        .font(.system(size: side * 0.6, weight: .heavy, design: .rounded))
                        .foregroundStyle(MinePalette.number(cell.adjacent))
                        .minimumScaleFactor(0.5)
                }
            } else {
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .fill(Appearance.shared.theme.surface)
                    .shadow(color: .black.opacity(0.18), radius: side * 0.04, y: side * 0.03)
                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(isHinted ? GameAccent.third.color : Appearance.shared.theme.border, lineWidth: isHinted ? max(2, side * 0.1) : 1)
                if cell.isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.system(size: side * 0.5))
                        .foregroundStyle(GameAccent.first.color)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: cell.isOpen)
        .accessibilityLabel(label)
    }
}
