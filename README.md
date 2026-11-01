# EST

EST is a free, open-source iPhone and iPad game about finding patterns in cards. It is
inspired by SET, but it has its own name, artwork, and code.

The deck has 81 cards. Each card combines four traits:

- count: 1, 2, or 3
- color: red, blue, or yellow
- shape: circle, square, or triangle
- fill: solid, shaded, or outline

Find three cards where every trait is either the same on all three cards or
different on all three cards. Game Center is optional. You can play alone,
pass one phone around the table, or play a live duel across two devices.

## Play

- Solo 81 clears the full deck against the clock. A personal best stays on
  the device, and an eligible run can also go to Game Center.
- Quick 27 uses the 27 solid cards for a shorter round. The fill trait
  stays fixed, so you check three traits instead of four.
- Duel lets you race another player on one phone or across two devices. On iPad,
  four players can share one table with a buzzer on each edge. Buzz first, then
  tap the three cards before the claim window closes.
- The tutorial teaches the rule with worked examples,
  and the math explorer lets you see the deck as a four-dimensional space.
- You can choose a color theme, pick a fill style, and turn sound
  effects or haptics on and off.

Solo leaderboard timing uses a monotonic clock and rejects physically
impossible completion times before submitting to Game Center. Hinted runs
remain local-only.

Hints keep the run off the Game Center leaderboard, but you can still set a
local personal best. EST has no ads or subscriptions. An optional one-time
support purchase adds a permanent supporter mark, optional Dusk card colors, and
an optional warm background,
while leaving every mode and gameplay feature free for everyone.

## Why EST

I love SET. I have given away more copies of it than of any other game. Its
rules are also a neat piece of mathematics: the 81 cards are the points of
AG(4,3), a four-dimensional affine space over a field with three elements.
EST is my attempt to make that structure visible without turning the game
into a textbook.

The name shuffles its own letters while you play. The cards use square shapes
and simple marks. That is about as far as the homage goes.

If you have never played the original, [buy a copy of
SET](https://www.playmonster.com/brands/set/). It is a near-perfect game.

## The mathematics

Represent a card as four base-3 digits: count, color, shape, and fill. A valid
set is a line in AG(4,3), which means the three cards add up to zero in every
coordinate modulo 3. Once you choose two cards, that rule gives you one and
only one completing card. The 81-card deck contains 1080 such sets.

The same rule explains a few endgame details. The whole deck sums to zero,
and every set you remove also sums to zero. The cards left at the end must
therefore sum to zero too. Three leftover cards would make a set, so a game
ends with either a perfect clear or at least six cards that contain no set.

A set-free group of cards is called a cap. Giuseppe Pellegrino proved that the
largest cap in AG(4,3) has 20 cards, so any 21 cards contain a set. Later work
by Croot, Lev, Pach, Ellenberg, and Gijswijt established how the maximum cap
size grows in higher dimensions. EST's endgame screen shows the cap you
finished against.

Further reading:

- Davis and Maclagan, "The Card Game SET," *The Mathematical Intelligencer*,
  2003.
- McMahon, Gordon, Gordon, and Gordon, "The Joy of SET," Princeton University
  Press, 2016.
- Ellenberg and Gijswijt, "On large subsets of F_q^n with no three-term
  arithmetic progression," *Annals of Mathematics*, 2017.

## Build

EST is an XcodeGen project for iPhone and iPad. You need Xcode, an iOS 17 SDK, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.30 or newer.

The Xcode project is generated from `project.yml`. Edit that file, then run:

```sh
xcodegen generate
xcodebuild -project EST.xcodeproj -scheme EST \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Game Center features need an App Store Connect app record and the Game Center
capability. The leaderboard identifiers are `est.solo.completion.time` and
`est.quick.completion.time`. Two signed-in devices, or a device and a
simulator, are needed to test a network duel.

Do not hand-edit `EST.xcodeproj`. Regenerate it after adding or removing a
source file.

### Forks and telemetry

The first-party build reports to the dedicated EST Worker, with anonymous
diagnostics enabled by default on new installs and adjustable in Settings. If
you distribute a fork, set your own `ESTTelemetryEndpoint` and
`ESTFeedbackEndpoint` Info.plist
build settings—or leave either unset—only after reviewing the collection
contract and privacy policy. Also replace the Centaur Labs team,
bundle identifier, Game Center configuration, and optional StoreKit product
identifiers with values you control. App Store publishing also requires an
explicit `EST_TEAM_ID` for your Apple Developer account.

## Repository layout

- `EST/Models` contains the card model, set math, game engine, and multiplayer
  sessions.
- `EST/Views` contains the SwiftUI screens and reusable card and button views.
- `ESTUITests` contains the stable screenshot tests used for App Store metadata.
- `appstore` contains the listing copy, metadata generator, and release assets.
- `telemetry` contains the optional aggregate diagnostics intake Worker and schema.
- `project.yml` is the source of truth for the Xcode project.

## Contributing

Bug reports, copy edits, and small code changes are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the local build and test workflow. Open
an issue before a larger change so the direction is clear, then include the
clean build command above in your pull request or issue notes.

For security reports, see [SECURITY.md](SECURITY.md).

Keep the set-validation logic in `Card`, and keep table behavior in
`GameEngine`. That separation lets the tutorial, solo game, and multiplayer
views use the same rules.

## Privacy

EST stores preferences and personal bests on the device. Optional anonymous
diagnostics send one coarse aggregate record per week when enabled and
configured, including
activity totals such as games started, games completed, and sets found; they
never include personal data or per-game events. Game Center handles its own
account, leaderboard, and matchmaking data. See the [privacy policy](PRIVACY.md)
and [telemetry details](docs/telemetry.md).

## License

The code and artwork are available under the [MIT License](LICENSE). The
license does not grant rights to the SET trademark.

SET is a registered trademark of Cannei, LLC, and the game is published by
PlayMonster LLC. EST is not affiliated with, sponsored by, or endorsed by
either company.

## Android

The offline Kotlin/Jetpack Compose port is in [`android/`](android/README.md).
Version 1.3.0 (185) follows the latest iOS home and ports Solo 81, configurable
Quick 27, Daily Deal, tutorials, training, hints, saved games, themes,
local personal bests, play-style statistics, the mathematics explorer, and
shared-device multiplayer from the iOS sources. See the [Android spec](docs/android.md) for scope and
the Google rankings follow-up.
