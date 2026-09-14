# Shell extraction plan

Goal: a small library of polished, simple mobile games that share one shell.
EST is the first consumer. SEEP, a flood-fill game, is the second.

## Layout

This repo becomes the monorepo. One `project.yml`, local Swift packages, one
app target per game.

```
Packages/GameShell/       chrome, settings, audio, telemetry, feedback, support, Game Center, run store
Packages/GridKit/         grid layout + board view, level store, seeded random
EST/                      unchanged path; table code (engine, party, network) stays here
SEEP/                     second app target (flood-fill game)
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

`GameAccent` (`first`, `second`, `third`, `danger`) is the palette slot.
`Theme.color(for:)` and `highlight(for:)` hold their tables on `GameAccent`;
`Card.Tint.color` delegates through `Card.Tint.gameAccent`, an extension that
lives in `Card.swift`. `GameAccent.identity` lists the three identity slots
for swatch rows and confetti defaults. `ConfettiView` takes `colors: [Color]`
and a shape builder (default circle); `ConfettiView.cards(tints:)` in
`CardView.swift` supplies EST's symbols. `Appearance.playerColor(for:)` reads
slots. The `estCardRotation` environment key moved next to `CardView`.

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

### Phase 7. SEEP app

- `project.yml`: target `SEEP`, bundle `com.centaur-labs.seep`, scheme,
  entitlements with Game Center, `SEEP/Resources/Assets.xcassets`.
- `SEEP/Models/FloodBoard.swift`: `cells: [[Int]]`, `colors: Int`,
  `flood(to:)` via BFS from the origin, `isSolved`, `moves`, `par` (greedy
  solver at generation, then padded). Undo is a stack of boards.
- `SEEP/Models/FloodLevels.swift`: three packs by board size (10, 14, 18)
  and color count (4, 5, 6). Every level is a seed, so a pack is a formula.
- Views: `FloodGameView` (grid, move counter, color buttons through
  `.buttonStyle(.game(...))`, undo and restart in the chrome row),
  `LevelGridView`, `FloodTutorialView` (three steps on a live 6x6 board),
  title screen using the shell frame.
- Game Center: `seep.pack.<size>.moves` leaderboards, `BEST_SCORE`
  ascending. Stats: solved per pack, best moves, current streak.
- Icon: parameterize `scripts/generate-app-icons.swift` by app.

### Phase 8. Scripts and listing

`scripts/appstore.sh` reads `APP` (`est` or `seep`) and takes `BUNDLE_ID`,
app record id, leaderboard list and product id from
`appstore/<app>/app.json`. `appstore/devices.mjs` stays shared.
`appstore/appstore.md` and `metadata.mjs` move under `appstore/est/`.
`capture.sh` and `ScreenshotTests` take the scheme name. SEEP needs its own
`ScreenshotTests` target.

## Per-game onboarding checklist

No game ships without every item. EST is the reference for each one.

1. **Guided first play.** A tutorial with a live board, first launch only,
   gated by `<product>.hasSeenTutorial`, replayable from a rules sheet. Steps:
   the goal, the one action, a worked example, one worked failure, a
   practice board the player solves, then the table rules. Five to seven
   steps. Same board size on every step.
2. **A "why" for every failure.** When a move is wrong or a game is lost,
   the game says which rule broke, in one line, from the same code the
   engine uses to judge it. Never restate the rule in a view.
3. **One explainer screen.** The idea behind the game, hands-on, reachable
   from Settings and the rules sheet. EST: the Math visualizer. SEEP: flood
   fill, and why greedy is not optimal. Minesweeper: constraint logic.
   Picross: line solving.
4. **Hints that teach.** A hint shows the next good move and marks the run
   as hinted, so it keeps a personal best but never enters the leaderboard.
5. **Stats that read back.** A Play Style screen: what the player does well,
   what they miss, in the game's own terms.
6. **Screenshots of all of the above.** The App Store set shows the tutorial
   and the explainer, not only the board.

## Decisions (MZ, 2026-09-14)

1. Telemetry: one Worker for every game. The batch schema gains an `app`
   string (`"est"`, `"seep"`). The Worker repo needs the matching change
   before SEEP ships; EST keeps sending without the field until then.
2. Support purchase in every game. Product id pattern `<prefix>.support`.
   Each app needs its own IAP record and review screenshot.
3. GitHub repo renamed `michellzappa/est` -> `michellzappa/games`. Old URLs
   redirect. The local folder is still `ios-est`; MZ renames it.
4. The flood game is **SEEP**. Target `SEEP`, folder `SEEP/`, bundle
   `com.centaur-labs.seep`, defaults prefix `seep`, product `seep.support`.

## Touch list

| Phase | Files moved | Files edited | New |
|---|---|---|---|
| 1 | 0 | `project.yml` | 2 `Package.swift`, 2 stub files |
| 2 | 0 | `Appearance`, `GameAccent`, `ConfettiView`, `CardView`, 6 views, `Card.swift` | `GameAccent.identity` |
| 3 | 0 | `Telemetry`, `Feedback`, `SupportStore`, `ESTApp`, `project.yml` | `GameIdentity` |
| 4 | 14 | every caller, for `public` and `import GameShell` | none |
| 5 | 0 | `SettingsView`, `ESTApp` | `CardAppearance` |
| 6 | 0 | `BoardGridView`, `PartyGameView` | 4 GridKit files |
| 7 | 0 | `project.yml`, icon script | ~10 SEEP files |
| 8 | `appstore/*` under `appstore/est/` | `appstore.sh`, `capture.sh`, `metadata.mjs` | `app.json` per app |

Unknowns: how much of `Telemetry` assumes EST event names in its `Event`
enum, and whether `SupportView` copy references cards. Both surface in Phase
3 and 4 as edits, not design changes.

## Progress

- Phase 1: done. `Packages/GameShell` and `Packages/GridKit` exist and are
  linked into the EST target.
- Phase 2: done. `Appearance`, `GameAccent`, `ConfettiView`, `ButtonStyles`,
  `GlassHelpers`, `SupportView`, `FeedbackView`, `LeaderboardView` have no
  `Card` reference. Remaining EST-only sites: the fill preview and
  `PlayStyleView` (Phase 5).
- Phase 3: done. `GameIdentity` lives in `GameShell`; EST installs `.est` in
  the `App` initializer. `Telemetry`, `Feedback`, `SupportStore` derive
  every key, header, path and product id from it. The Worker is
  multi-product (`PRODUCTS` table, `product` column, migration 0001
  applied, `?product=` on `/v1/community`), deployed 2026-09-14.
  `SupportStore.productID` is optional; nil hides the purchase.
- Phase 4: done. Fourteen files moved into `GameShell` and made public.
  `LeaderboardView` is the shell frame over `[LeaderboardBoard]`; EST's tabs
  are `ESTLeaderboardView`. `SupportView(confetti:)` takes the game's
  confetti. `fillStyle` moved to `CardAppearance` in EST.
  `Theme.cardSurface/cardBorder/cardSlotBorder` are now
  `surface/border/slotBorder`. `RunStore<Run>` replaces `SoloRunStore`'s
  body; EST keeps a thin `SoloRunStore` wrapper with the old key.
- Phase 5: done. `SettingsView` in the shell owns the universal sections and
  three slots: `look`, `game`, `afterPrivacy`. The Support section hides
  when `supportProductID` is nil. `ESTSettingsView` fills the slots with
  the fill picker, Game and Data sections, and Community Pulse, and owns
  the reset dialog and the Play Style sheet.
- Phase 6: done. `GridKit` holds `GridLayout` (fit, frames, hit test),
  `GridBoardView` (tap and drag in grid coordinates), `LevelStore` (packs,
  best, stars, unlock), `SeededGenerator` and `Seed` (SplitMix64, daily
  and per-level seeds). `BoardGridView`, `PartyGameView` and
  `NetworkPartyGameView` read their cell size from `GridLayout`.
