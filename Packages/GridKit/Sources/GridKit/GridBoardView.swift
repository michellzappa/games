import SwiftUI

/// A board of square cells. The view fits the grid into its space, draws
/// one `cell` per position, and reports taps and drags in grid
/// coordinates. Flood-It taps; Flow drags; both use this.
public struct GridBoardView<Cell: View>: View {
    public struct Position: Hashable {
        public let row: Int
        public let column: Int

        public init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }
    }

    private let columns: Int
    private let rows: Int
    private let gap: CGFloat
    private let maximumSide: CGFloat
    private let onTap: ((Position) -> Void)?
    private let onDragEnter: ((Position) -> Void)?
    private let onDragEnd: (() -> Void)?
    private let cell: (Position, CGFloat) -> Cell

    @State private var dragPosition: Position?
    @State private var dragMoved = false

    /// `cell` receives the position and the cell side, so a cell can scale
    /// its content. `onDragEnter` fires once each time the finger enters a
    /// new cell; `onDragEnd` when the finger lifts after a drag. A touch
    /// that never leaves its first cell is a tap.
    public init(
        columns: Int,
        rows: Int,
        gap: CGFloat = 4,
        maximumSide: CGFloat = .infinity,
        onTap: ((Position) -> Void)? = nil,
        onDragEnter: ((Position) -> Void)? = nil,
        onDragEnd: (() -> Void)? = nil,
        @ViewBuilder cell: @escaping (Position, CGFloat) -> Cell
    ) {
        self.columns = columns
        self.rows = rows
        self.gap = gap
        self.maximumSide = maximumSide
        self.onTap = onTap
        self.onDragEnter = onDragEnter
        self.onDragEnd = onDragEnd
        self.cell = cell
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = GridLayout.fitting(
                columns: columns, rows: rows, gap: gap, in: proxy.size, maximumSide: maximumSide
            )
            let origin = layout.origin(centeredIn: proxy.size)

            ZStack(alignment: .topLeading) {
                ForEach(0..<(rows * columns), id: \.self) { index in
                    let position = Position(row: index / columns, column: index % columns)
                    let frame = layout.frame(index: index, origin: origin)
                    cell(position, layout.side)
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let hit = layout.cell(at: value.location, origin: origin) else { return }
                        let position = Position(row: hit.row, column: hit.column)
                        if dragPosition == nil {
                            dragPosition = position
                            dragMoved = false
                            onDragEnter?(position)
                        } else if position != dragPosition {
                            dragPosition = position
                            dragMoved = true
                            onDragEnter?(position)
                        }
                    }
                    .onEnded { _ in
                        if let dragPosition, !dragMoved {
                            onTap?(dragPosition)
                        }
                        if dragMoved {
                            onDragEnd?()
                        }
                        dragPosition = nil
                        dragMoved = false
                    }
            )
        }
    }
}
