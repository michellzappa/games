# EST App Store Connect workflow

This follows the release setup used by Septena, adapted to EST's single iPhone/iPad
target and the installed `asc` CLI. `appstore/appstore.md` contains the
listing copy. `metadata.mjs` turns it into the JSON files accepted by `asc
metadata`. The UI test captures six screens: title, Solo 81, Quick 27,
one-phone Duel, rules, and the math explorer. The same test target runs on
both an iPhone and an iPad simulator, because it makes no device or
orientation assumption.

## Local capture and validation

Install the renderer once:

```bash
npm install --prefix appstore
npm exec --prefix appstore -- playwright install chromium
```

Then generate the raw captures, product-page panels, and ASC upload set:

```bash
./scripts/appstore.sh prepare
```

Metadata-only validation, which does not require a simulator or generated
screenshots, is available with:

```bash
node appstore/metadata.mjs
node appstore/validate.mjs --metadata-only
```

That regenerates the Xcode project from `project.yml`, captures every device
class with Apple's 9:41 status bar, renders the marketing panels, generates
metadata, and runs both local validators. Set `EST_SIMULATOR_NAME` to override
the simulator for a single capture run.

`appstore/devices.mjs` is the single source of truth for the device classes.
Every other script reads the simulator name, pixel size, and ASC display type
from it:

| Device | Pixels | ASC display type | Simulator |
| --- | --- | --- | --- |
| `iphone69` | 1320×2868 | `IPHONE_69` | iPhone 16 Pro Max |
| `ipad13` | 2064×2752 | `IPAD_PRO_3GEN_129` | iPad Pro 13-inch (M4) |

Apple requires a screenshot set for every device class the app supports, and
EST ships `TARGETED_DEVICE_FAMILY: 1,2`. A missing iPad set blocks submission,
so `validate.mjs` fails when one device class has no screenshots. There is no
Mac screenshot set.

Capture one device class at a time with:

```bash
./appstore/capture.sh ipad13 light
```

Panels are authored once. Each device renders in a shared design space 1320
units wide, and Playwright scales that space to the real pixel size, so the
type scale is identical on iPhone and iPad while the proportions differ. A
panel can override its frame geometry for one device under
`overrides.<deviceKey>` in `product-page.json`; the mathematics panel does this
to nudge its frame down on iPhone only.

The product-page source is [product-page.json](product-page.json). Each panel
keeps its source capture, headline, accent, and alt text as editable metadata.
The renderer writes the finished images to
`appstore/product-page/<device>/en-US/` and mirrors the same files into
`appstore/screenshots/<device>/en-US/` for upload. To render every device class
without recapturing:

```bash
./scripts/appstore.sh product-page
```

## One-time App Store Connect setup

The public App Store Connect REST API does not create the initial app record.
The installed CLI uses Apple's web session flow for that one step:

```bash
./scripts/appstore.sh create your-apple-account@example.com
```

The command prompts securely for the Apple Account password and two-factor
code. It creates iOS app `EST`, bundle ID `com.centaur-labs.est`, SKU `EST`, and
version `1.0.0`. Copy the returned numeric App Store Connect app ID.

Then run:

```bash
./scripts/appstore.sh setup <APP_ID>
```

This sets the listing basics, categories (Games / Puzzle), full territory
availability, a free price schedule, and the two Game Center leaderboards:
`est.solo.completion.time` and `est.quick.completion.time`.

The leaderboard setup uses centiseconds, with score-range floors of 1,800
(18.00 seconds) for Solo 81 and 450 (4.50 seconds) for Quick 27. The setup
script requires an `asc` version that supports
`ELAPSED_TIME_CENTISECOND`; it will stop instead of creating a leaderboard
with the legacy millisecond formatter. `asc` 4.x supports that formatter;
`asc` 3.x does not. The scripts target `asc` 4.x, which renamed
`review submit --build` to `--build-id` and removed `--public-provider-id`
from `web apps create`.

## First release only: no release notes

Apple rejects `whatsNew` on an app that has never been released, with
"Attribute 'whatsNew' cannot be edited at this time". Version 1.0.0 has nothing
to be new against. Keep the copy in `appstore.md` for the next version and set
`EST_INITIAL_RELEASE=1` for every command that regenerates metadata until 1.0.0
ships:

```bash
EST_INITIAL_RELEASE=1 ./scripts/appstore.sh upload-screenshots <APP_ID>
```

## Optional support purchase

Create this product manually in App Store Connect before submitting:

- Product ID: `est.support`
- Type: Non-Consumable
- Display name: `Support EST`
- Price: `$10.00` / `£10.00` / `€10.00` in the relevant storefronts
- Description: `A one-time gift that keeps EST free and independent. No gameplay is locked. Supporters receive a mark, optional Dusk card colors, a warm background setting, and early-access invites when available.`

The app is playable without a purchase. `Config/ESTSupport.storekit` contains
the local StoreKit test configuration, and the generated EST scheme uses it for
simulator testing.

Supporter operations remain deliberately personal and opt-in:

- Add supporters to an early-access TestFlight group manually when a build is
  ready; the app cannot assign Apple TestFlight groups itself.

The scripts use `https://github.com/michellzappa/games` for the public repository.
If the repository moves, update `appstore/appstore.md`, `PRIVACY.md`, and the
setup script before uploading.

## Build, upload, and submit

The publishing script does not contain a default Apple Developer Team ID. Set
`EST_TEAM_ID` to the team that owns your app before using `setup` or
`publish`. `create` no longer needs it: `asc` 4.x removed the provider flag
and the web session prompts for the team when the account owns more than one.

The App Store Connect API key can be supplied through
`~/.est-asc-secrets` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`). The
`EST_ASC_SECRETS` environment variable can point to another file. The `asc`
CLI receives the same key through `ASC_PRIVATE_KEY_PATH` in the wrapper.

```bash
./scripts/appstore.sh publish <APP_ID>
./scripts/appstore.sh upload-screenshots <APP_ID>
```

`publish` archives the Release build, uploads it, waits for processing, creates
or updates the `1.0.0` version, and applies version metadata. The local Mac
must have an Apple Distribution certificate/profile available for automatic
signing; the App Store Connect API key authenticates API/upload operations but
does not replace the local distribution identity.

Before submission, complete the App Privacy declaration in the CLI web-session
flow, create the review contact details, and answer the export-compliance and
age-rating questions. EST has no ads, no subscriptions, and no user-generated
content. It has one optional non-consumable support purchase and no non-exempt
encryption. Reviewer notes are in `appstore/review-notes.txt`. After publishing,
the review contact and notes can be created or updated from the CLI:

```bash
EST_REVIEW_EMAIL=you@example.com \
EST_REVIEW_PHONE='+1 555 0100' \
./scripts/appstore.sh review-details <APP_ID>
```

The first and last name default to `Michell Zappa`; override them with
`EST_REVIEW_FIRST_NAME` and `EST_REVIEW_LAST_NAME` if needed.

Finally, inspect the readiness report and submit explicitly:

```bash
asc validate --app <APP_ID> --version 1.0.0 --platform IOS --output table
./scripts/appstore.sh submit <APP_ID>
```
