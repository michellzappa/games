import GameShell
import GridKit
import SwiftUI

/// A pack picker and its thirty boards. A board shows its stars, or a lock
/// until the one before it is done.
struct LevelGridView: View {
    @Binding var pack: FloodPack
    let onPlay: (FloodPack, Int) -> Void
    let onBack: () -> Void

    private let stats = SEEPStats.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                GameExitButton(accessibilityLabel: "Back to title", action: onBack)
                Spacer()
                Text("Boards")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 46, height: 46)
            }
            .padding(.horizontal, 20)

            Picker("Pack", selection: $pack) {
                ForEach(FloodPack.allCases) { pack in
                    Text(pack.name).tag(pack)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            Text("\(pack.subtitle). \(stats.levels.completedCount(pack: pack.rawValue, levels: FloodPack.levelCount)) of \(FloodPack.levelCount) done.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(0..<FloodPack.levelCount, id: \.self) { index in
                        levelCell(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Appearance.shared.gameBackground)
    }

    private func levelCell(_ index: Int) -> some View {
        let record = stats.levels.record(pack: pack.rawValue, index: index)
        let unlocked = stats.levels.isUnlocked(pack: pack.rawValue, index: index)
        return Button {
            onPlay(pack, index)
        } label: {
            VStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                if record.completed {
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { star in
                            Image(systemName: star < record.stars ? "star.fill" : "star")
                                .font(.system(size: 9))
                        }
                    }
                    .foregroundStyle(GameAccent.third.color)
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(height: 11)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.game(record.completed ? .secondary : .quiet, tint: .second, size: .medium))
        .disabled(!unlocked)
        .accessibilityLabel(accessibilityLabel(index, record: record, unlocked: unlocked))
    }

    private func accessibilityLabel(_ index: Int, record: LevelRecord, unlocked: Bool) -> String {
        if !unlocked { return "Board \(index + 1), locked" }
        if record.completed { return "Board \(index + 1), \(record.stars) stars, best \(record.best ?? 0) moves" }
        return "Board \(index + 1)"
    }
}
