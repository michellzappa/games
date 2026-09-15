#!/usr/bin/env bash
# Stage the selected raw captures in App Store Connect order, unframed.
#
#   appstore/stage.sh <app> <device> [light|dark]
#     app: est | seep
#     device: iphone69 | ipad13
#
# This writes the plain simulator captures. `npm run product-page` overwrites
# the same directory with the framed marketing panels, so run stage.sh alone
# only when the listing should show bare screenshots.
set -euo pipefail

APP="${1:?usage: appstore/stage.sh <app> <iphone69|ipad13> [light|dark]}"
DEVICE="${2:?usage: appstore/stage.sh <app> <iphone69|ipad13> [light|dark]}"
APPEARANCE="${3:-light}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/appstore/$APP/raw/$DEVICE/$APPEARANCE"
OUT="$ROOT/appstore/$APP/screenshots/$DEVICE/en-US"

# devices.mjs is the single source of truth for the exported pixel size.
SIZE="$(cd "$ROOT" && node --input-type=module -e \
  'import { device } from "./appstore/devices.mjs"; const d = device(process.argv[1]); console.log(`${d.width}x${d.height}`);' \
  "$DEVICE")" || { echo "Unknown device: $DEVICE"; exit 1; }

[ -d "$RAW" ] || { echo "No raw capture directory: $RAW"; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT"

# app.json lists the marketing order.
shots=($(cd "$ROOT" && node --input-type=module -e \
  'import { app } from "./appstore/app.mjs"; console.log(app(process.argv[1]).shots.join(" "));' \
  "$APP"))
for index in "${!shots[@]}"; do
  name="${shots[$index]}"
  source="$RAW/$name.png"
  [ -f "$source" ] || { echo "Missing raw screenshot: $source"; exit 1; }
  printf -v number '%02d' "$((index + 1))"
  cp "$source" "$OUT/${number}-${name}-${SIZE}.png"
done

echo "✓ staged ${#shots[@]} $DEVICE screenshots → appstore/$APP/screenshots/$DEVICE/en-US"
