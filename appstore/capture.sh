#!/usr/bin/env bash
# Capture raw App Store screenshots from an app's UI-test target.
#
#   appstore/capture.sh <app> <device> [light|dark]
#     app: est | seep (a directory under appstore/ with an app.json)
#     device: iphone69 | ipad13
#
# The raw captures go to appstore/<app>/raw/<device>/<appearance>/. They are kept
# separate from the final staged screenshots so the marketing order can change
# without re-running the simulator.
#
# The UI test makes no device or orientation assumptions, so the same test
# target produces both sets. Only the simulator changes.
set -euo pipefail

APP="${1:?usage: appstore/capture.sh <app> <iphone69|ipad13> [light|dark]}"
DEVICE="${2:?usage: appstore/capture.sh <app> <iphone69|ipad13> [light|dark]}"
APPEARANCE="${3:-light}"
case "$APPEARANCE" in
  light|dark) ;;
  *) echo "usage: appstore/capture.sh <app> <device> [light|dark]"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# app.json names the scheme and the UI-test target that captures.
app_field() {
  node --input-type=module -e \
    'import { app } from "./appstore/app.mjs"; console.log(app(process.argv[1])[process.argv[2]]);' \
    "$APP" "$1"
}
SCHEME="$(app_field scheme)" || { echo "Unknown app: $APP"; exit 1; }
UI_TEST_TARGET="$(app_field uiTestTarget)"

# devices.mjs is the single source of truth for the simulator per device class.
SIM_DEFAULT="$(node --input-type=module -e \
  'import { device } from "./appstore/devices.mjs"; console.log(device(process.argv[1]).simulator);' \
  "$DEVICE")" || { echo "Unknown device: $DEVICE"; exit 1; }
SIM_NAME="${SIMULATOR_NAME:-${EST_SIMULATOR_NAME:-$SIM_DEFAULT}}"
SIM_ID="$(xcrun simctl list devices available | grep "$SIM_NAME (" | head -1 | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()')"
[ -n "$SIM_ID" ] || { echo "No '$SIM_NAME' simulator found"; exit 1; }

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl ui "$SIM_ID" appearance "$APPEARANCE" 2>/dev/null || true
xcrun simctl status_bar "$SIM_ID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode notSupported \
  --batteryState charged --batteryLevel 100 2>/dev/null || true

RESULT="/tmp/${APP}-appstore-${DEVICE}-${APPEARANCE}.xcresult"
OUT="$ROOT/appstore/$APP/raw/$DEVICE/$APPEARANCE"
rm -rf "$RESULT" "$OUT"
mkdir -p "$OUT"

# Export attachments even when the test fails. A failed run still holds the
# captures it managed to take, plus the UI hierarchy at the failure, and that
# is the only way to diagnose a device-specific break.
set +e
xcodebuild test \
  -project EST.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -resultBundlePath "$RESULT" \
  -only-testing:"$UI_TEST_TARGET/ScreenshotTests" \
  -configuration Debug

TEST_STATUS=$?
set -e

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT" >/dev/null

python3 - "$OUT" <<'PY'
import json
import os
import re
import sys

directory = sys.argv[1]
manifest_path = os.path.join(directory, "manifest.json")
with open(manifest_path, encoding="utf-8") as handle:
    manifest = json.load(handle)

for attachment in manifest[0]["attachments"]:
    source = os.path.join(directory, attachment["exportedFileName"])
    if not os.path.exists(source):
        continue
    name = attachment["suggestedHumanReadableName"].split("_0_")[0]
    # Keep only the deliberate captures. A failed run also exports UI
    # hierarchies, debug descriptions, synthesized events, snapshots and a
    # screen recording, which otherwise pile up in raw/.
    if not re.fullmatch(r"[a-z0-9-]+(\.png)?", name) or name.startswith("00-"):
        os.remove(source)
        continue
    if not name.endswith((".png", ".txt")):
        name += ".png"
    os.rename(source, os.path.join(directory, name))

os.remove(manifest_path)
print("✓ captured:", ", ".join(sorted(name for name in os.listdir(directory) if name.endswith(".png"))))
PY

if [ "$TEST_STATUS" -ne 0 ]; then
  echo "✗ The UI test failed on $DEVICE. Exported whatever it captured to" >&2
  echo "  appstore/$APP/raw/$DEVICE/$APPEARANCE for diagnosis. Do not ship these." >&2
  exit "$TEST_STATUS"
fi

echo "✓ raw screenshots → appstore/$APP/raw/$DEVICE/$APPEARANCE"
