# Shell extraction plan

Goal: a small library of polished, simple mobile games that share one shell.
EST is the first consumer. Flood-It (working name) is the second.

## Layout

This repo becomes the monorepo. One `project.yml`, local Swift packages, one
app target per game.

```
Packages/GameShell/       chrome, settings, audio, telemetry, feedback, support, Game Center, run store
Packages/GridKit/         grid layout + board view, level store, seeded random
EST/                      unchanged path; table code (engine, party, network) stays here
FloodIt/                  second app target
appstore/<app>/           per-app listing, screenshots, review notes
scripts/appstore.sh       takes an app name
```

Not extracted in this pass: `PlayerStats` (every field is a SET trait) and
the table layer (`GameEngine`, `PartySession`, `NetworkPartySession`,
`ClaimRace`, `NetMessages`, `BoardGridView`, `PilesView`). They stay in `EST/`.

## EST-specific coupling inside the shell candidates

1. `Card.Tint` used as a color name in `Appearance`, `GameAccent`,
   `ConfettiView`, `SettingsView`, `SupportView`, `FeedbackView`,
   `LeaderboardView`, `PlayStyleView`. About 30 sites. None need a card; they
   need "palette slot 0/1/2".
2. String identity: `estPlayerStats`, `estTelemetry*`, `estFeedbackEndpoint`,
   `est.solo.completion.time`, `est.quick.completion.time`, `est.support`,
   the `ESTTelemetryEndpoint` and `ESTFeedbackEndpoint` Info.plist keys, the
   `X-EST-Telemetry-Schema` header, the `EST/Telemetry/pending.json` path.
3. `GameEngine` types in `SoloRunStore` (`SavedRun`) and `ESTLeaderboard`
   (`Variant`, eligibility).

## Phases

Each phase ends with `xcodegen generate` and a clean build. Bump
`CURRENT_PROJECT_VERSION` before each build. One commit per phase.

### Phase 1. Empty packages wired in

Add `Packages/GameShell` and `Packages/GridKit` with a `Package.swift`, iOS
17, no dependencies. Add them to `project.yml` as `packages:` and to the EST
target as `dependencies:`. Build. Proves the XcodeGen and SPM plumbing before
any file moves.

### Phase 2. Palette slot replaces `Card.Tint` in shared code

In `Appearance`: `Theme.color(for: Card.Tint)` becomes `color(for slot:
PaletteSlot)` where `PaletteSlot` is `enum { case first, second, third }`.
`Card.Tint.color` stays as an EST extension that maps `red -> .first` and so
on. `GameAccent` already exists for this; extend it and use it in the view
sites. `ConfettiView` takes `colors: [Color]` and a shape builder (default
circle); EST passes its symbols. `Appearance.playerColor(for:)` reads slots.

Result: `Appearance`, `GameAccent`, `ConfettiView`, `ButtonStyles`,
`GlassHelpers` compile with no reference to `Card`. No file moves yet.

### Phase 3. `GameIdentity`

One struct in the shell:

```swift
public struct GameIdentity {
    public let name: String            // "EST"
    public let defaultsPrefix: String  // "est"
    public let supportProductID: String?
    public let telemetryEndpointInfoKey: String
    public let feedbackEndpointInfoKey: String
    public let telemetrySchemaHeader: String
    public let pendingBatchDirectory: String
}
```

Installed once in the `App` init: `GameIdentity.current = .est`. `Telemetry`,
`Feedback`, `SupportStore`, `AppIconManager` read it. UserDefaults keys become
`"\(prefix)TelemetryEnabled"`, which keeps the existing EST keys byte-for-byte
so installed users lose nothing. Leaderboard ids do not go here; a game owns
its own leaderboard enum.

### Phase 4. Move the pure files

`ButtonStyles`, `GlassHelpers`, `GameAudio`, `GameAccent`, `Appearance`
(minus fill style), `ConfettiView`, `Telemetry`, `Feedback`, `FeedbackView`,
`SupportStore`, `SupportView`, `GameCenterManager`, `AppIconManager`,
`LeaderboardView` (takes a leaderboard id and a formatter, not a `Variant`).
Every exposed type becomes `public`: views, `@Observable` classes and their
members, every `init`.

`Appearance.fillStyle` (solid/pinstriped) is a card concept. It stays in EST
as `CardAppearance`. The shell `Appearance` keeps theme, motion, contrast,
color-blind assist.

`SoloRunStore` becomes `RunStore<Run: Codable>` with the three-day expiry;
EST instantiates it with `GameEngine.SavedRun`.

### Phase 5. `SettingsView` splits

The shell owns the Form and the rows for look, motion, audio, diagnostics,
support, feedback, version. EST-only rows (fill style, theme preview with
three `CardView`s, Community Pulse, Play Style) go into a `@ViewBuilder
gameSections` parameter that EST passes in. `CommunityPulseView` and
`PlayStyleView` stay in EST.

### Phase 6. `GridKit`

New code, no moves:

- `GridLayout`: given available size, columns, rows and gap, returns cell side
  and origin. This is the sizing math now inside `BoardGridView` and
  `PartyGameView`. EST's `BoardGridView` adopts it so there is one copy.
- `GridBoardView<Cell: View>`: square cells, tap and drag with cell
  hit-testing, `@ViewBuilder cell(row, col)`.
- `LevelStore`: packs, per-level best value, stars, unlock rule, Codable in
  UserDefaults under `GameIdentity.defaultsPrefix`.
- `SeededGenerator`: `RandomNumberGenerator` from a `UInt64` seed, plus
  `Seed.daily()`. Every board generator takes a generator, so a daily puzzle
  is a seed and nothing else.

### Phase 7. Flood-It app

- `project.yml`: target `FloodIt`, bundle `com.centaur-labs.floodit`, scheme,
  entitlements with Game Center, `FloodIt/Resources/Assets.xcassets`.
- `FloodIt/Models/FloodBoard.swift`: `cells: [[Int]]`, `colors: Int`,
  `flood(to:)` via BFS from the origin, `isSolved`, `moves`, `par` (greedy
  solver at generation, then padded). Undo is a stack of boards.
- `FloodIt/Models/FloodLevels.swift`: three packs by board size (10, 14, 18)
  and color count (4, 5, 6). Every level is a seed, so a pack is a formula.
- Views: `FloodGameView` (grid, move counter, color buttons through
  `.buttonStyle(.game(...))`, undo and restart in the chrome row),
  `LevelGridView`, `FloodTutorialView` (three steps on a live 6x6 board),
  title screen using the shell frame.
- Game Center: `floodit.pack.<size>.moves` leaderboards, `BEST_SCORE`
  ascending. Stats: solved per pack, best moves, current streak.
- Icon: parameterize `scripts/generate-app-icons.swift` by app.

### Phase 8. Scripts and listing

`scripts/appstore.sh` reads `APP` (`est` or `floodit`) and takes `BUNDLE_ID`,
app record id, leaderboard list and product id from
`appstore/<app>/app.json`. `appstore/devices.mjs` stays shared.
`appstore/appstore.md` and `metadata.mjs` move under `appstore/est/`.
`capture.sh` and `ScreenshotTests` take the scheme name. Flood-It needs its
own `ScreenshotTests` target.

## Open decisions (before Phase 3)

1. Telemetry for the second app: same Worker with an `app` field, a second
   Worker, or none. The Worker is in another repo.
2. Support purchase in every game, or EST only. If every game, the product id
   pattern is `<prefix>.support`.
3. Repo name. `ios-est` holding `FloodIt/` reads wrong. A GitHub rename keeps
   redirects; `Telemetry.sourceURL` needs an update.
4. Flood-It's real name. "Flood-It!" is a live app.

## Touch list

| Phase | Files moved | Files edited | New |
|---|---|---|---|
| 1 | 0 | `project.yml` | 2 `Package.swift`, 2 stub files |
| 2 | 0 | `Appearance`, `GameAccent`, `ConfettiView`, 6 views, `Card.swift` | `PaletteSlot` |
| 3 | 0 | `Telemetry`, `Feedback`, `SupportStore`, `ESTApp`, `project.yml` | `GameIdentity` |
| 4 | 14 | every caller, for `public` and `import GameShell` | none |
| 5 | 0 | `SettingsView`, `ESTApp` | `CardAppearance` |
| 6 | 0 | `BoardGridView`, `PartyGameView` | 4 GridKit files |
| 7 | 0 | `project.yml`, icon script | ~10 Flood-It files |
| 8 | `appstore/*` under `appstore/est/` | `appstore.sh`, `capture.sh`, `metadata.mjs` | `app.json` per app |

Unknowns: how much of `Telemetry` assumes EST event names in its `Event`
enum, and whether `SupportView` copy references cards. Both surface in Phase
3 and 4 as edits, not design changes.

## Progress

- Phase 1: done. `Packages/GameShell` and `Packages/GridKit` exist and are
  linked into the EST target.
