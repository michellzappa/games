# EST — agent notes

EST is a SwiftUI iPhone/iPad spinoff of the card game SET. 81 cards, four traits,
three values each. The app name shuffles its letters in-app (EST/TSE/STE/…);
the canonical product name is EST.

## Build

XcodeGen is the source of truth. Never hand-edit `EST.xcodeproj`.

```
xcodegen generate
xcodebuild -project EST.xcodeproj -scheme EST -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Run `xcodegen generate` after adding or removing a source file under `EST/`.
A missing new file surfaces as misleading "has no member" errors in other
files, not as "file not found". Files under `Packages/` are picked up by SPM
without a regenerate.

## Packages

`docs/shell-extraction.md` is the plan and the progress log. The repo is
becoming a monorepo for a small library of games; EST is the first.

- `Packages/GameShell`: chrome, `Appearance`, `GameAccent`, buttons, glass,
  audio, confetti, telemetry, feedback, support purchase, Game Center,
  `LeaderboardView`, `RunStore`, `GameIdentity`. No game logic, no `Card`.
- `Packages/GridKit`: grid primitives for square-cell puzzle games.
  `GridLayout` is the one copy of the cell-fit math; every board view in
  EST reads its side, frames and centers from it. `GridBoardView` reports
  taps and drags as `(row, column)`. `LevelStore` keeps pack progress.
  `SeededGenerator` and `Seed` make a level a seed and a daily a date; a
  board generator must take a `RandomNumberGenerator`, never call
  `.random()` directly.
- Everything the app reaches must be `public`, including memberwise inits,
  which Swift never makes public: write the `init` by hand. A missing
  `public` shows as "inaccessible due to 'internal' protection level", or,
  inside a large SwiftUI expression, as "unable to type-check this
  expression in reasonable time". Extract the row into a function first, and
  the real error appears.
- `GameIdentity.install(_:)` runs in the `App` initializer, before any shell
  code. Every persisted key, Info.plist key, header and product id derives
  from `GameIdentity.current.product`, so EST's stored keys did not change.
- Shell views take game content as parameters: `SupportView(confetti:)`,
  `LeaderboardView(boards:onOpen:)`, `ConfettiView(colors:shape:)`,
  `SettingsView(about:confetti:look:game:afterPrivacy:)`. EST's versions are
  `ConfettiView.cards()`, `ESTLeaderboardView`, `ESTSettingsView`.
- Card-only look settings live in `CardAppearance` (fill style), not in the
  shell `Appearance`.

Versioning: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in
`project.yml`. Before every agent validation/build, bump
`CURRENT_PROJECT_VERSION` by 1, then run `xcodegen generate`; never reuse a
build number for a new build. This applies to ordinary work-in-progress builds
as well as builds handed to MZ for testing. Keep `MARKETING_VERSION` unchanged
unless the task is a release/versioning task. Settings shows the numbers.

The shared scheme is declared in `project.yml` (`scheme: testTargets: []`).
Do not remove it: without it a regenerate leaves the project scheme-less and
`xcodebuild -scheme EST` fails.

macOS ships bash 3.2, where `"${array[@]}"` on an empty array trips `set -u`.
Use `${a[@]+"${a[@]}"}` when an argument is optional. This broke
`scripts/appstore.sh` only when the App Review phone was omitted.

The green gate is a clean build. MZ tests by hand — do not boot simulators or
drive the UI unless asked.

## Screenshots and UI tests

`appstore/devices.mjs` is the single source of truth for device classes. Every
script reads the simulator name, pixel size, and ASC display type from it.
Apple requires a screenshot set for every device class the app supports, so
iPhone and iPad are both mandatory while TARGETED_DEVICE_FAMILY is "1,2".

- A SwiftUI `Form` is lazy. A row below the fold is absent from the
  accessibility tree, not merely unhittable, so `waitForExistence` fails before
  any scroll happens. Scroll first, then re-check existence each pass. This is
  what `scrollToTap` in `ScreenshotTests.swift` does.
- Wait on `GameExitButton` to detect a running game. The deck pile is not
  universal: the iPad duel table seats players instead of showing piles.
- `capture.sh` exports attachments even when the test fails, then exits
  non-zero. A failed run still holds its captures and the UI hierarchy at the
  failure, which is the only way to diagnose a device-specific break.
- `capture.sh` keeps only lowercase-slug names. A failed run also exports UI
  hierarchies, debug descriptions, synthesized events, snapshots, and a screen
  recording.
- The renderer refuses to render a missing capture unless `--allow-missing` is
  passed. A silent placeholder once produced six blank iPad panels that passed
  size validation and were ready to upload.

## Invariants

- Card identity: `id = (count-1)*27 + tint*9 + symbol*3 + fill`. The set math
  in `Card.swift` uses trit sums mod 3; `completing(_:_:)` derives the unique
  third card. Do not duplicate set-validation logic anywhere else.
- Table rules live only in `GameEngine`: 12 cards, deal +3 while no EST is
  present, replace in place when at 12, compact when above 12.
- A match celebrates for `GameEngine.celebrationDuration` before replacements
  deal; input is blocked meanwhile and the solo clock ends at the final match
  moment, not after its celebration. `onAutoAdvance` fires after the engine
  advances on its own — the network host rebroadcasts there.
- Buttons: every control the player taps uses `GameButtonStyle` through
  `.buttonStyle(.game(role, tint:, size:))` in `ButtonStyles.swift`. Three
  rules: one `.primary` per screen, tints come from `GameAccent` (mapped onto
  the active card palette, never the system accent), and a row is one size so
  it cannot taper or wrap. Do not use `.bordered` or
  `.borderedProminent` in game UI. Settings is a Form and keeps native rows.
- Every card-shaped surface draws through `CardChrome` in `CardView.swift`:
  the face, the back, a pile layer, an empty slot. It owns the corner
  fraction, the surface color, and the two border colors. Do not write a
  `RoundedRectangle` for a card anywhere else. The piles once used their own
  radius and their own gray, so a themed board sat above mismatched piles.
- Liquid Glass: use the `glassPanel`/`glassButtonSurface` helpers in
  `GlassHelpers.swift` (iOS 26 glass, material fallback). Do not call
  `glassEffect` directly elsewhere.
- One interrupted solo run survives a relaunch. `GameEngine.savedRun(hintUsed:)`
  and `restore(_:)` move the table as card ids; `SoloRunStore` holds the JSON
  in UserDefaults and drops a run older than three days. A restored run sets
  `wasPaused`, so it keeps a personal best and never reaches the leaderboard.
  Ending a game from the exit dialog clears the save, because the dialog
  promises the run is lost. Party and network runs are never saved.
- `GameFlipButton` turns the card symbols to face another player, through the
  `estCardRotation` environment value that `CardView` reads. Only the symbols
  turn: the grid keeps the same cards in the same cells, so a player reading
  the table does not lose their place. It sits opposite `GameExitButton` in the
  same chrome row, and only on shared-device screens: solo and local party. A
  network game gives every player their own device, so it has no flip button.
  Every tap is a quarter turn, on every screen: half a turn moves only
  triangles and the three-symbol arrangement, so it reads as almost nothing.
- `PartySession` wraps `GameEngine` for one-device multiplayer. Solo views talk
  to `GameEngine` directly.
- Multi-device party (`NetworkPartySession`) runs over a `GKMatch` (online or
  nearby via Game Center matchmaking). The device with the lowest gamePlayerID
  is host and owns the only real `GameEngine`; clients send buzz/select events
  and render full-state JSON snapshots (`NetMessages.swift`). Times cross the
  wire as remaining seconds, never dates. Claim/lockout rules live in
  `ClaimRace.Configuration`; local and network party sessions reuse them; do
  not fork them.
- `BoardGridView` and `PilesView` take plain values (with engine convenience
  initializers) so local engines and remote snapshots share the same views.
- A network game ends only when fewer than `PartySession.minimumPlayerCount`
  devices remain. Otherwise the player leaves their seat and play continues;
  their won cards stay out of play, so the deck math is unchanged.
- Host migration: the lowest gamePlayerID among connected devices is host, so
  a host that leaves hands the role to the next device. The new host rebuilds
  authority from its last snapshot through `GameEngine.adoptAsHost`. The
  snapshot carries `outOfPlayIDs` and per-player `collectedIDs`, all of them
  cards that were face up, so nothing secret crosses the wire; the remaining
  deck is reshuffled locally because its order was never sent. A trio that was
  still celebrating resolves during the handover, and no claim survives it.
  Palette slots are pinned per player in `colorIndexes`, so a departing player
  does not recolor the rest.
- Real matchmaking needs the app record + Game Center capability live in App
  Store Connect; two signed-in devices (or device + simulator) are needed to
  test it.
- Game Center leaderboard IDs: `est.solo.completion.time` (full 81-card solo)
  and `est.quick.completion.time` (Quick 27). Scores are centiseconds
  (elapsed-time format, ascending). Both must be created in App Store Connect
  with exactly these IDs before submission works.
- Quick 27 is `GameEngine.Variant.quick`: the 27 solid-fill cards, 9 on the
  table. The fill trait is constant there, so the set math is untouched.
- Trait explanations come from `Card.audit(_:_:_:)`, which returns one
  `TraitVerdict` per trait. `violationDescriptions` and the tutorial's
  `TraitAuditView` both read it; do not restate the rule in a view.
- `TutorialView` is the guided tour (goal, traits, worked set, worked non-set,
  practice board, table rules). First launch shows it over the title screen,
  gated by the `hasSeenTutorial` UserDefaults key; the rules sheet replays it.
  Every card it draws is `TutorialView.cardSide`, on every step: fixed cells,
  not flexible grid columns, because a `CardView` inside a `ScrollView` has no
  reliable height to grow into, and a card that changes size between steps
  reads as a different kind of thing.
- Look settings live in `Appearance.shared` (theme, motion, contrast) and
  `CardAppearance.shared` (fill style). `Card.Tint.color` delegates to the
  active theme through `GameAccent`; never hardcode card colors in views.
  The icon generator script keeps its own baked colors.
- Signing is automatic with no team hardcoded in `project.yml`, so forks can
  choose their own Apple Developer account. App Store archive scripts require
  `EST_TEAM_ID`; simulator builds still need `CODE_SIGNING_ALLOWED=NO`.
- iPhone and iPad (`TARGETED_DEVICE_FAMILY: 1,2`); iPhone remains portrait,
  while iPad supports portrait and landscape so four seats can use every edge.
  Square-ish large-screen iPhone windows use the same responsive four-seat
  layout when there is enough room.
- Solo rules MZ decided (2026-08-29): no mismatch penalty, auto-deal the extra
  3 cards, matchmaking open to friends + nearby + strangers. A hinted solo run
  keeps the local personal best but never submits to the leaderboard.
- Modes MZ decided: solo and duel. The UI exposes two-player duel on iPhone,
  and two- or four-player one-device tables on iPad; iPad matchmaking can also
  fill the existing four-player network roster.
- Never attach `.task` to a `Group` whose branches are mutually exclusive.
  SwiftUI applies the modifier to each branch. A state change that switches the
  branch destroys that view and cancels the task that set the state. This kept
  Community Pulse on "Loading…" forever. `CommunityPulseView` in
  `ESTSettingsView.swift` now holds one `VStack` and a `Phase` enum, and the
  `.task` sits on the stable container.

## SEEP

The second app, a flood-fill puzzle. `SEEP/` mirrors `EST/`: `App/`,
`Models/`, `Views/`, `Resources/`. Build:

```
xcodebuild -project EST.xcodeproj -scheme SEEP -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

- `FloodBoard` owns the one move (flood the corner region) and the greedy
  solver. `FloodGame` owns a round: par is the greedy move count, the limit
  is par + 3, stars are 3 at par, 2 one over, 1 for a finish. Do not put
  rules in views.
- A level is a seed: `Seed.level(pack:index:)`. Changing a pack id, the
  level count, or `FloodBoard.generate` changes every board players have
  already seen. Add a new pack instead.
- The daily is `Seed.daily(salt: "seep")` on the UTC day, 14 by 14, five
  colors. No daily leaderboard; the streak is local.
- Leaderboards `seep.pool.moves`, `seep.lake.moves`, `seep.ocean.moves`:
  total best moves over all 30 boards, submitted only when every board is
  done and none was hinted. Integer, ascending. Create them in App Store
  Connect with these ids.
- Telemetry keys are `SEEPEvent`; the Worker whitelists them under `seep`.
  Adding a key means editing both.
- Icons: `swift scripts/generate-seep-icon.swift <AppIcon png>` then
  `generate-app-icons.swift orchard|dusk` for the alternates.

## DIG

The third app, a minesweeper. `DIG/` mirrors `SEEP/`. Build with
`-scheme DIG`.

- `MineBoard` owns the board and the three moves: dig (floods zeros),
  flag, chord. `MineSolver` owns the two rules (saturation, subset) and is
  the one source for hints, the loss reason, and no-guess verification. Do
  not restate a rule in a view.
- The start cell is seeded and always a zero. `MineLevel.board()` retries
  seeds until the solver clears the board without a guess, or the size's
  `noGuessAttempts` run out; the second value marks a board "may need a
  guess". Quarry (16 by 30, 99 mines) never verifies; Patch verifies on
  the first try 85 percent of the time; the whole search is under 300 ms.
- Leaderboards `dig.patch.time`, `dig.field.time`, `dig.quarry.time`:
  centiseconds, ascending, floors 100 / 1000 / 3000. A hinted round and a
  daily never submit.
- `GridBoardView` gained `onLongPress`; a long press cancels the tap.
- `TimeFormat` moved from EST into the shell.

## App Store Connect

Every script takes the app first: `./scripts/appstore.sh <app> <command>`,
`appstore/capture.sh <app> <device>`, `node appstore/metadata.mjs --app
<app>`. `appstore/<app>/app.json` holds the names, bundle id, scheme,
categories, leaderboards and screenshot order; `appstore/<app>/appstore.md`
is the listing copy. See `appstore/README.md`.

EST: the app record is `6806817604` (in `app.json`). The App Store name is
`EST - Card Trios`; the product name stays EST. SEEP and DIG: no record
yet; `appId` is empty until `create` runs, then `setup` creates the three
leaderboards each, and `seep.support` / `dig.support` follow the same IAP
steps as EST.

`scripts/appstore.sh` needs `asc` 4.x and `jq`. Version 3.x has no
`ELAPSED_TIME_CENTISECOND` formatter, and 4.x renamed flags the script uses.

One App Store Connect API key serves every app in the team. Reuse it. Do not
make a second key:

```
export EST_TEAM_ID=992N457T8D
export EST_ASC_SECRETS=~/.cartogram-secrets
```

Order matters in `setup`. Each rule below comes from a failed run:

- Do not pass `--bundle-id` to `asc app-setup info set`. App creation binds the
  bundle ID. Sending it again fails with "already been used".
- `PUZZLE` is a subcategory of `GAMES`, not a second category. Use
  `--primary GAMES --primary-subcategory-one GAMES_PUZZLE`.
- Create the Game Center detail before the leaderboards. A new app record has
  none, and the leaderboard call fails without one. The detail also clears the
  runtime error `GKError 15`, `5019 no game matching descriptor`.
- Use `grep`, not `rg`. `rg` is absent from some PATHs. The old `rg` check
  failed open and reported a false "asc does not support
  ELAPSED_TIME_CENTISECOND".
- Availability failure must not stop the run. It used to abort `setup` before
  the leaderboards were created.

In-app purchase product IDs accept only letters, digits, periods, and
underscores. The bundle ID `com.centaur-labs.est` has a hyphen, so the support
purchase cannot mirror it. The ID is `est.support`, matching the short scheme
of the Game Center IDs. It lives in `SupportStore.swift` and
`Config/ESTSupport.storekit`, and both must agree with App Store Connect.

Apple requires a screenshot set for every device class the app supports. EST
ships `TARGETED_DEVICE_FAMILY: 1,2`, so iPhone and iPad sets are both
mandatory. `appstore/devices.mjs` is the single source of truth for the device
classes; `appstore/validate.mjs` fails when a class has no screenshots.

These rules come from the real 1.0.0 publish. Each one failed first:

- Pass `--build-number` from `project.yml`. In local-build mode `asc publish`
  auto-resolves the build number from `--initial-build-number` (default 1) and
  ignores `CURRENT_PROJECT_VERSION`. Build 1 of 1.0.0 shipped that way, so the
  number Settings showed did not match the repo. `publish_app` now reads
  `project.yml` and passes it.
- Creating an app in the web UI makes a version named `1.0`, not `1.0.0`. The
  binary carries `CFBundleShortVersionString` from `MARKETING_VERSION`, and a
  build cannot attach to a version with a different string. Rename the version
  with `asc versions update --version-id ID --version 1.0.0`.
- Apple rejects `whatsNew` on an app that has never been released: "Attribute
  'whatsNew' cannot be edited at this time". Generate metadata with
  `INITIAL_RELEASE=1` until 1.0.0 ships (`EST_INITIAL_RELEASE` still works).
- App Review details require `contactPhone`. The script fails up front now.
- `asc review details-create` leaves `demoAccountRequired` true, which makes
  App Review expect credentials EST does not have. The script pins it false.
- App Privacy is not "Data Not Collected". Diagnostics default to on, so EST
  transmits Usage Data (product interaction), Diagnostics, and a weekly
  rotating device identifier. All are unlinked and not used for tracking. If
  the diagnostics default changes, this declaration changes with it.

An in-app purchase is a separate review item with its own readiness rules.
`est.support` stays MISSING_METADATA until all three exist:

- a version-scoped localization, `asc iap versions localizations create`. The
  description is capped at 45 characters.
- availability, `asc iap pricing availability set`. Read the app's own
  territory list from `asc pricing availability territory-availabilities` and
  reuse it, so the purchase matches the app instead of drifting.
- a review screenshot, `asc iap review-screenshots create`. Use this command,
  not `asc iap versions images`. That one manages the promotional image, which
  demands its own dimensions and fails every device screenshot with
  IMAGE_INCORRECT_DIMENSIONS. The review screenshot endpoint accepts a plain
  1320x2868 capture. The 640x920 size in Apple's help text is a red herring
  for this endpoint.

Add the in-app purchase to the review submission before submitting. `asc
review submit` attaches only the build, and a submitted review submission
refuses new items with "reviewSubmission state does not allow adding more
items". Build the submission by hand when a version ships an in-app purchase:

```
asc review submissions-create --app APP_ID --platform IOS
asc review items-add --submission SUB --item-type appStoreVersions --item-id VERSION_ID
asc review items-add --submission SUB --item-type inAppPurchaseVersions --item-id IAP_VERSION_ID
asc review submissions-submit --id SUB --confirm
```

To recover from a submission that is missing an item, cancel it with
`asc review submissions-update --id SUB --canceled=true --confirm`. The version
then reads DEVELOPER_REJECTED, which means editable again, not rejected by
Apple. Rebuild the submission with every item and submit again.

Two steps need the App Store Connect web UI. The `asc` web session fails at
Apple's session-info step with status 401, and the public API rejects the
availability bootstrap:

- Creating the app record.
- Pricing and Availability. EST is free in every territory except China
  mainland. China requires a government ISBN for a game that carries an in-app
  purchase, and EST carries the support purchase.

## Not built yet

- Nothing tracked here right now.
