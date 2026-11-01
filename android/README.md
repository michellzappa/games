# EST for Android

Native Kotlin / Jetpack Compose port. See [the product spec](../docs/android.md).

## Build and install

Use JDK 17 or newer and Android SDK 36. Set `JAVA_HOME` and `ANDROID_HOME`, or
open this directory in Android Studio and let it select the SDK.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

The GitHub 1.3.0 (185) preview is a non-debuggable release APK signed with the
existing development certificate, so it updates earlier A17 installs.
The debug APK can also be shared directly for device testing. It uses a debug key;
it is not the production Play Store build. The application ID is
`com.centaurlabs.est`; Android 8.0 or later is supported.

This Android release matches iOS **1.3.0 (185)**, source commit
`9bd12a94fa90594f8a90ca79c528660cb6edece2`. Version values live in `app/build.gradle.kts`. The committed Gradle wrapper
and dependency versions make the project self-contained; first build downloads
dependencies from Google/Maven Central.

## Release signing

An unsigned bundle can be built without signing credentials:

```sh
./gradlew :app:bundleRelease
```

For distribution, provide a dedicated upload key through environment variables:

```sh
export EST_ANDROID_KEYSTORE=/absolute/path/to/upload.jks
export EST_ANDROID_KEY_ALIAS=est
# Set EST_ANDROID_STORE_PASSWORD and EST_ANDROID_KEY_PASSWORD securely.
./gradlew :app:bundleRelease :app:assembleRelease
```

Outputs: `app/build/outputs/bundle/release/app-release.aab` and
`app/build/outputs/apk/release/`. Never commit keys or passwords. Preserve the
upload key for updates and enroll in Play App Signing when publishing. Do not
publish the unsigned bundle or the debug APK as a production release.

## First Play release

1. Confirm the final package name before creating the Play listing.
2. Configure signing, then upload the signed bundle to internal testing.
3. Test on physical phone and tablet: airplane mode; both complete game variants;
   pause; background; process death; resume; hints; sounds; dark theme; rotation;
   TalkBack and large fonts. No simulator was driven during development.
4. Add store title **EST — Card Trios**, original EST artwork, phone/tablet
   screenshots, content rating and a public privacy-policy URL. This Android
   build collects no data and requests no network or runtime permissions; do not copy the iOS
   telemetry disclosure unchanged.
5. Complete Play Console's applicable account testing and release requirements.

Same-device multiplayer is included. Google Play Games rankings are not yet
configured; the leaderboard control remains disabled, as on signed-out iOS. The spec describes the two Google leaderboards,
score units, eligibility, retry behavior and required Console configuration.

## Manual acceptance checklist

- First launch opens the tutorial; subsequent launches open home.
- Resume appears on the root menu; starting a new solo replaces the previous solo save.
- Daily games preserve the solo save, use the identical Swift shuffle, and retain daily best/streak.
- Cards have the same traits/IDs and table rules as the iOS version.
- Matching cards stay visible for 900 ms and cannot be selected twice.
- Backgrounding pauses solo timing; returning resumes it. Exit and hint dialogs keep the clock running.
- Process death during celebration neither loses nor duplicates the trio.
- Personal bests persist separately for Quick 27 and Solo 81.
- Hints, invalid-trait feedback, practice streak and settings work offline.
- Small/landscape windows scroll; cards and controls remain reachable.
- TalkBack announces the traits, selected state and hints.

## Privacy

Saves, settings, personal bests and the practice streak live in app-private local
storage. Backup is disabled. This build has no network permission, analytics,
ads, billing SDK or login. Uninstalling deletes the data.

## Source-port build

Build 185 extends the source port with the refreshed Solo/Together home, toolbar,
Quick trait selector, daily deal, two-step hints, run insights and adaptive training.
The earlier source-port work replaces the initial Android design with the iOS card geometry, palette,
pinstriped default, title, HUD, piles, tutorial, training, statistics, mathematics,
local duel rules, original audio and icon. See the spec for source mapping and
platform-rendering boundaries. Corner markers are off unless color-blind assist
is enabled. Tests validate rules and geometry; pixel parity is not yet certified.
