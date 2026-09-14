# EST Privacy Policy

EST does not collect, sell, or share personal data for gameplay or anonymous
diagnostics.

If you enable **Share anonymous diagnostics** in Settings, and the build has a
diagnostics endpoint configured, EST sends one aggregate product-diagnostics
record per ISO week. It contains the app version, iOS major version, coarse
counts of games started, games completed, sets found, mode usage, and a small
set of feature settings. It does not contain your name, Game Center ID, cards,
scores, exact times, or per-game events. Diagnostics are enabled by default on
new installs and can be turned off at any time; turning them off deletes
pending diagnostics, hides Community Pulse aggregate stats, and stops new
collection. Existing installs keep their current choice. The
first-party EST build reports to the dedicated EST Worker; forks and
distributors can replace or omit the endpoint. See the
[telemetry details](docs/telemetry.md).

If you use **Send feedback**, the text you submit is sent over the internet to
the first-party EST feedback Worker, which forwards it to
`mz@centaur-labs.io`. The message includes the app version, build, iOS major
version, and coarse device family to help diagnose issues. The email field is
optional. If you fill it in, the address travels with the message and is used
only as the reply address. Leave it empty and the message carries nothing that
identifies you. Feedback does not
require anonymous-diagnostics consent and is not stored in the Worker's D1
database, but the email delivery provider and recipient may retain the message.
Do not include sensitive information.

When a distributor configures an endpoint, that distributor is responsible for
the service's hosting, retention, and privacy practices. The included Worker
retains raw aggregate records for up to 180 days before scheduled cleanup.

The game stores preferences, personal best times, and aggregate play-style
learning stats on your device. Play-style stats include counts such as valid
sets by number of differing traits and which traits were involved in an
incorrect attempt. They are never uploaded. If you use Game Center, Apple
handles the Game Center account, leaderboard, and matchmaking data under
[Apple's privacy policy](https://www.apple.com/legal/privacy/).
EST does not create a separate account or user database.

EST has no advertising, behavioral tracking, or subscriptions. Its optional
anonymous diagnostics are described above. It offers one
optional, non-consumable support purchase through Apple's App Store. The
purchase does not unlock gameplay. Apple handles payment and purchase history
under its privacy policy. EST does not ask for access to your contacts, photos,
location, health data, microphone, or camera.

For support, use **Send feedback** in Settings or open an issue in the [EST
GitHub repository](https://github.com/michellzappa/games/issues).
This policy may change if the app's data practices change.

Last updated: 2026-08-30.
