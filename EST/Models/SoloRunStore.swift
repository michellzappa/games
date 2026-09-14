import Foundation
import GameShell

extension GameEngine.SavedRun: SavedRunRecord {}

/// EST's one interrupted solo run. The key predates the shell, so it stays
/// unprefixed and an upgraded install keeps its saved table.
enum SoloRunStore {
    static let shared = RunStore<GameEngine.SavedRun>(key: "soloRunInProgress")

    static func save(_ run: GameEngine.SavedRun?) { shared.save(run) }
    static func load() -> GameEngine.SavedRun? { shared.load() }
    static func clear() { shared.clear() }
}
