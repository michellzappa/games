import CoreGraphics

/// Square cells in a grid: how big each cell is, where the grid sits, and
/// where each cell is. Pure geometry, so a board view, a hit test, and a
/// flight animation all agree on the same frames.
public struct GridLayout: Equatable {
    public let columns: Int
    public let rows: Int
    public let gap: CGFloat
    public let side: CGFloat

    public init(columns: Int, rows: Int, gap: CGFloat, side: CGFloat) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.gap = max(0, gap)
        self.side = max(0, side)
    }

    /// The largest square cell that fits `columns` by `rows` cells with
    /// `gap` between them inside `size`, capped at `maximumSide`.
    public static func fitting(
        columns: Int,
        rows: Int,
        gap: CGFloat,
        in size: CGSize,
        maximumSide: CGFloat = .infinity
    ) -> GridLayout {
        let columns = max(1, columns)
        let rows = max(1, rows)
        let bySide = min(
            (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns),
            (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        )
        return GridLayout(columns: columns, rows: rows, gap: gap, side: max(1, min(bySide, maximumSide)))
    }

    /// Rows needed for `count` cells in `columns` columns, at least one.
    public static func rows(for count: Int, columns: Int) -> Int {
        max(1, Int((Double(count) / Double(max(1, columns))).rounded(.up)))
    }

    public var width: CGFloat { CGFloat(columns) * side + CGFloat(columns - 1) * gap }
    public var height: CGFloat { CGFloat(rows) * side + CGFloat(rows - 1) * gap }
    public var size: CGSize { CGSize(width: width, height: height) }

    /// Top-left of the grid when centered in `container`.
    public func origin(centeredIn container: CGSize) -> CGPoint {
        CGPoint(x: (container.width - width) / 2, y: (container.height - height) / 2)
    }

    /// Frame of the cell at `row`, `column`, relative to `origin`.
    public func frame(row: Int, column: Int, origin: CGPoint = .zero) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(column) * (side + gap),
            y: origin.y + CGFloat(row) * (side + gap),
            width: side,
            height: side
        )
    }

    /// Frame of the cell at a row-major `index`.
    public func frame(index: Int, origin: CGPoint = .zero) -> CGRect {
        frame(row: index / columns, column: index % columns, origin: origin)
    }

    public func center(index: Int, origin: CGPoint = .zero) -> CGPoint {
        let rect = frame(index: index, origin: origin)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// The cell under `point`, or nil in a gap or outside the grid. A drag
    /// that crosses a gap reports nil there, so a path never skips a cell.
    public func cell(at point: CGPoint, origin: CGPoint = .zero) -> (row: Int, column: Int)? {
        let x = point.x - origin.x
        let y = point.y - origin.y
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let pitch = side + gap
        let column = Int(x / pitch)
        let row = Int(y / pitch)
        guard x - CGFloat(column) * pitch < side, y - CGFloat(row) * pitch < side,
              column < columns, row < rows
        else { return nil }
        return (row, column)
    }
}
