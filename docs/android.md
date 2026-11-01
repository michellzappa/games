# EST Android — iOS source port

The iOS implementation is the product specification. Android must reproduce
its own artwork, rules, screen structure, labels and offline interactions;
independent redesigns and unsolicited visual additions are not acceptable.
The earlier v0.1 specification described a simplified reimplementation and is
superseded by this source-port specification.

Baseline: iOS **1.3.0 (185)** at `9bd12a94fa90594f8a90ca79c528660cb6edece2` (2026-11-01). Android uses the same version/build numbers.

## Source mapping

| iOS source | Android implementation | Verification |
| --- | --- | --- |
| `EST/Models/Card.swift` | `Game.kt`, `EstCard` | Every card ID, all 1,080 sets, training near misses, practice uniqueness |
| `EST/Models/GameEngine.swift` | `Game.kt`, `Game` | 1,000 complete games, 81/27 decks, timing, pauses, save restoration |
| `EST/Views/CardView.swift` | `CardGeometry.kt`, `Artwork.kt` | Nonlinear 2/3 power scaling, optical corrections, equilateral centers, stroke sizing |
| `Packages/GameShell/.../Appearance.swift` | `Artwork.kt`, `MainActivity.kt` | Primary/Orchard sRGB components and highlights copied directly |
| `EST/Models/CardAppearance.swift` | `GameModel.kt`, `Artwork.kt` | Pinstriped default; optional shaded fill |
| `EST/Views/BoardGridView.swift`, `GridLayout.swift` | `Artwork.kt` | Larger fit of three columns or three rows, 10-point gaps, 150/240 caps |
| `EST/Views/PilesView.swift` | `Artwork.kt` | 52-point stacks, counts, progress, visible-set count |
| `EST/Views/TitleView.swift` | `MainActivity.kt`, `Rules.kt` | Solo/Together panel navigation, top toolbar, 84-point demo cards, Quick trait selector |
| `EST/Views/SoloGameView.swift` | `MainActivity.kt` | mm:ss clock, rotate-symbols control, full-mode two-step hint, exit confirmation |
| `EST/Views/TutorialView.swift` | `Tutorial.kt` | Six steps, 92-point examples, exactly-one-set practice gate |
| `EST/Views/TrainingView.swift` | `MainActivity.kt` | 96-point cards, balanced set/non-set questions, near-miss bias, streak |
| `EST/Models/PlayerStats.swift`, `PlayStyleView.swift` | `PlayerStats.kt`, `PlayStyle.kt` | Attempts, accuracy, differing-trait counts/timing, errors, conditions |
| `EST/Views/Math/*` | `Mathematics.kt` | Trit editor, forced third card, 81-card grid, nine slices, verified cap |
| `EST/Models/ClaimRace.swift`, `PartySession.swift` | `Party.kt`, `PartyScreen.kt` | Exclusive 5s claims, 4s + 1s/penalty lockout, score floor, collected cards |
| `Packages/GameShell/.../GameAudio.swift` | `scripts/generate_audio.py`, `GameAudio.kt` | Same voices, frequencies, envelopes, seeded noise and stereo balance |
| `Packages/GameShell/.../ConfettiView.swift` | `Confetti.kt` | 40 particles, original parameter ranges and motion equations |

## Artwork rules

- No always-visible corner letters. iOS's optional color-blind assist is off by
  default; its markers are top-right and appear only when enabled.
- Symbol side = `23 * (cardSide / 100)^(2/3)`; gap =
  `10 * (cardSide / 100)^(2/3)` in logical dp/points, not physical pixels.
- Square optical scale 0.95, circle 1, triangle 1.06. Triangle height is
  `width * sqrt(3)/2`. Square corners are 10% of the inner shape width.
- Stroke = `max(1.5, symbolSide * 0.09)` with half-stroke padding.
- Solid fills use the original diagonal highlight/color gradient without a rim.
  Shaded uses 0.24 alpha plus rim; stripes use the original step/width/round caps.
- Card corners are 12% of card side; selection scales to 1.06, celebration 1.10.
- Entry offsets/roll use the original card-ID formulas. Mismatches shake for
  400ms; explanations clear after five seconds. Solo matches fly to the played
  pile. The original PNG icon is reused, not the former invented vector icon.

## Offline scope and platform boundaries

Solo 81, Quick 27 with four fixed-trait choices, seeded Daily Deal, saved runs, tutorial, training, personal bests, learning stats,
math exploration and same-device 2/4-player games are implemented. Four seats
are offered on tablet-width windows. Saves and settings remain local.

Android typography, system dialogs, accessibility services and GPU shadow/corner
rendering use Android implementations. Apple's SF Symbols and Liquid Glass are
not available here; control glyphs and translucent surfaces are Android
implementations. These must not be described as pixel-identical without a
side-by-side render comparison. The math tests validate geometry, not screenshot
identity. The current iOS game is not built/launched by this task; repository
instructions reserve interactive device acceptance for MZ.

Network multiplayer, Game Center/Google rankings, StoreKit/Play Billing supporter
purchase and Community Pulse are outside this offline build. Dusk/supporter
cosmetics need the corresponding Android entitlement integration. The leaderboard
control is disabled while no Android ranking service is configured, matching the
iOS unauthenticated state. No network or runtime permissions are requested.

For Google rankings, provision Play Games Services, signing credentials and two
TIME leaderboards (Solo 81 / Quick 27). Google receives milliseconds, unlike iOS
centiseconds. Submit only unhinted uninterrupted completed games, with minimum
times 18s / 4.5s. Ranking service failures must never block offline play.

## Validation

Build 185 (2026-11-01): debug and signed release APKs. Nineteen unit tests cover
engine/card rules, geometry/teaching, local-party/statistics, all Quick trait
choices and restore, two-step hints, adaptive training, fastest-set eligibility,
and the larger landscape grid. The daily shuffle is compared against output
from the unchanged iOS Swift generator and Swift's standard-library shuffle for
2026-11-01, 2026-10-31 and leap day 2024-02-29.

Daily rounds never overwrite or delete a saved solo round. Completion keeps a
separate UTC-day best and consecutive-day streak. Hint/exit dialogs continue the
clock; only backgrounding the activity pauses it. Run completion shows fastest,
slowest, slowest set kind and most-missed trait.

The GitHub preview APK is a non-debuggable release build signed with the existing
development certificate so it can update the A17 installation without losing data.
It is a prerelease download, not a Play Store production signing setup. Android lint reports no errors;
remaining warnings are toolchain/dependency updates and launcher-resource advice.

Before production distribution: perform side-by-side iOS/Android visual
acceptance, real-device accessibility/gameplay testing, configure release signing,
and complete the Play listing/review. See `android/README.md` for commands.
