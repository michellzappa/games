import GameShell
import SwiftUI

/// The idea behind SEEP: flood fill is a breadth-first search, and the
/// greedy player is not the best player. Both are shown on a small board
/// where the exact best answer can be searched.
struct FloodExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board = FloodExplainerView.sample()
    @State private var wave = 0
    @State private var optimal: [Int]?

    private static func sample() -> FloodBoard {
        FloodLevel(kind: .practice, size: 6, colorCount: 3, seed: 424_242).board()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("01 / flood fill", "A move is a search") {
                        TutorialText.paragraph("The region is found by breadth-first search: start at the corner, visit every neighbor of the same color, repeat from each new cell. The wave below is that search, one ring at a time.")
                        waveBoard
                        HStack(spacing: 12) {
                            Button("Step") { wave += 1 }
                                .buttonStyle(.game(.secondary, tint: .second, size: .inline))
                            Button("Reset") { wave = 0 }
                                .buttonStyle(.game(.quiet, size: .inline))
                        }
                    }

                    section("02 / greedy", "The obvious strategy") {
                        TutorialText.paragraph("Greedy means: take the color that grows the region most right now. That is what the hint does, and what par measures. On this board greedy needs \(board.greedyPath().count) moves.")
                        pathRow(board.greedyPath())
                    }

                    section("03 / optimal", "Greedy is not always best") {
                        TutorialText.paragraph("The true minimum needs a search over every sequence of moves. That is easy on a 6 by 6 board and hopeless on a large one: the general problem is NP-hard. When the search finds a shorter path than greedy, beating par is possible.")
                        if let optimal {
                            pathRow(optimal)
                            Text(optimal.count < board.greedyPath().count
                                ? "Best: \(optimal.count) moves. Greedy: \(board.greedyPath().count)."
                                : "Best: \(optimal.count) moves. Greedy found it too.")
                                .font(.subheadline.weight(.semibold))
                        } else {
                            Button("Search this board") { optimal = Self.optimalPath(board) }
                                .buttonStyle(.game(.secondary, tint: .third, size: .inline))
                        }
                        Button {
                            var generator = SystemRandomNumberGenerator()
                            board = FloodBoard.generate(size: 6, colorCount: 3, using: &generator)
                            optimal = nil
                            wave = 0
                        } label: {
                            Label("Another board", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.game(.quiet, size: .inline))
                    }
                }
                .padding(24)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("The idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var waveBoard: some View {
        let rings = Self.rings(board)
        return FloodBoardView(board: board, highlightRegion: false)
            .overlay {
                GeometryReader { proxy in
                    let side = proxy.size.width / CGFloat(board.size)
                    ForEach(Array(rings.enumerated()), id: \.offset) { ring, cells in
                        if ring < wave {
                            ForEach(cells, id: \.self) { index in
                                Circle()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: side * 0.3, height: side * 0.3)
                                    .position(
                                        x: (CGFloat(index % board.size) + 0.5) * side,
                                        y: (CGFloat(index / board.size) + 0.5) * side
                                    )
                            }
                        }
                    }
                }
            }
            .frame(width: 216, height: 216)
            .frame(maxWidth: .infinity)
    }

    private func pathRow(_ path: [Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(path.enumerated()), id: \.offset) { _, color in
                Circle().fill(FloodPalette.color(color)).frame(width: 18, height: 18)
            }
        }
    }

    private func section<Content: View>(_ eyebrow: String, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPanel(cornerRadius: 20)
    }

    /// Cells of the corner region grouped by search distance from the
    /// corner, so the wave animation can show the search one ring at a time.
    private static func rings(_ board: FloodBoard) -> [[Int]] {
        let color = board.floodColor
        var distance = [Int](repeating: -1, count: board.cells.count)
        distance[0] = 0
        var frontier = [0]
        var rings: [[Int]] = []
        while !frontier.isEmpty {
            rings.append(frontier)
            var next: [Int] = []
            for index in frontier {
                let row = index / board.size, column = index % board.size
                var candidates: [Int] = []
                if row > 0 { candidates.append(index - board.size) }
                if row < board.size - 1 { candidates.append(index + board.size) }
                if column > 0 { candidates.append(index - 1) }
                if column < board.size - 1 { candidates.append(index + 1) }
                for candidate in candidates where distance[candidate] < 0 && board.cells[candidate] == color {
                    distance[candidate] = distance[index] + 1
                    next.append(candidate)
                }
            }
            frontier = next
        }
        return rings
    }

    /// Breadth-first over board states, so the first solved state found is
    /// a shortest path. Fine for 6 by 6 with three colors; never call this
    /// on a real level.
    static func optimalPath(_ start: FloodBoard) -> [Int] {
        var seen: Set<[Int]> = [start.cells]
        var queue: [(FloodBoard, [Int])] = [(start, [])]
        var head = 0
        while head < queue.count {
            let (board, path) = queue[head]
            head += 1
            if board.isSolved { return path }
            for color in 0..<board.colorCount where color != board.floodColor {
                var next = board
                next.flood(to: color)
                if seen.insert(next.cells).inserted {
                    queue.append((next, path + [color]))
                }
            }
        }
        return start.greedyPath()
    }
}
