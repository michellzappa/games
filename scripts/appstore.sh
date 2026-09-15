#!/usr/bin/env bash
# The CLI-first App Store Connect workflow, one app at a time.
#
#   ./scripts/appstore.sh <app> <command> [args]
#     app: est | seep (a directory under appstore/ with an app.json)
#
# Local assets:
#   ./scripts/appstore.sh est prepare
#
# ASC setup after the app record exists (APP_ID defaults to app.json's appId):
#   ./scripts/appstore.sh est setup [APP_ID]
#   ./scripts/appstore.sh est upload-screenshots [APP_ID]
#   ./scripts/appstore.sh est publish [APP_ID]
#   ./scripts/appstore.sh est review-details [APP_ID]
#   ./scripts/appstore.sh est submit [APP_ID]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${EST_TEAM_ID:-}"
ASC_SECRETS="${EST_ASC_SECRETS:-$HOME/.est-asc-secrets}"

APP="${1:-}"
[ -n "$APP" ] && [ -f "$ROOT/appstore/$APP/app.json" ] || {
  echo "usage: $0 <app> <command> [args]" >&2
  echo "apps: $(ls "$ROOT/appstore"/*/app.json 2>/dev/null | xargs -n1 dirname | xargs -n1 basename | tr '\n' ' ')" >&2
  exit 1
}
shift

# app.json is the source of truth for names, ids, categories, leaderboards.
app_json() {
  jq -r "$1" "$ROOT/appstore/$APP/app.json"
}
STORE_NAME="$(app_json .storeName)"
SUBTITLE="$(app_json .subtitle)"
SKU="$(app_json .sku)"
BUNDLE_ID="$(app_json .bundleId)"
SCHEME="$(app_json .scheme)"
DEFAULT_APP_ID="$(app_json '.appId // empty')"
VERSION="${APP_VERSION:-$(app_json .version)}"
LISTING="appstore/$APP"

load_asc_credentials() {
  if [ -f "$ASC_SECRETS" ]; then
    set -a
    source "$ASC_SECRETS"
    set +a
    export ASC_PRIVATE_KEY_PATH="${ASC_PRIVATE_KEY_PATH:-${ASC_KEY_PATH:-}}"
    export ASC_BYPASS_KEYCHAIN="${ASC_BYPASS_KEYCHAIN:-1}"
  fi
}

# project.yml is the source of truth for versions. Without this, asc local-build
# mode auto-resolves a build number from --initial-build-number (default 1) and
# the uploaded binary reports "1" while the repo says something else, so the
# number Settings shows no longer identifies the build. Each target has its
# own number, so read the one under this app's target.
project_build_number() {
  awk -v target="  $SCHEME:" '
    $0 == target { inside = 1; next }
    inside && /^  [A-Za-z]/ { inside = 0 }
    inside && /CURRENT_PROJECT_VERSION:/ { gsub(/[^0-9]/, "", $2); print $2; exit }
  ' FS=':' "$ROOT/project.yml"
}

require_team_id() {
  [ -n "$TEAM_ID" ] || {
    echo "Set EST_TEAM_ID to the Apple Developer Team ID before using this command." >&2
    exit 1
  }
}

usage() {
  sed -n '1,16p' "$0"
  echo ""
  echo "Commands: prepare | product-page | create <APPLE_ID> | setup [APP_ID] | upload-screenshots [APP_ID] | publish [APP_ID] | review-details [APP_ID] | submit [APP_ID]"
}

# Every device class the apps ship. Apple requires a screenshot set for each
# one, so iPad is not optional while TARGETED_DEVICE_FAMILY stays "1,2".
DEVICES=(iphone69 ipad13)

asc_device_type() {
  node --input-type=module -e \
    'import { device } from "./appstore/devices.mjs"; console.log(device(process.argv[1]).ascDeviceType);' \
    "$1"
}

product_page() {
  cd "$ROOT"
  for device in "${DEVICES[@]}"; do
    npm run product-page --prefix appstore -- --app "$APP" --device "$device"
  done
}

prepare() {
  cd "$ROOT"
  xcodegen generate
  for device in "${DEVICES[@]}"; do
    ./appstore/capture.sh "$APP" "$device" light
  done
  product_page
  node appstore/metadata.mjs --app "$APP"
  node appstore/validate.mjs --app "$APP"
  asc metadata validate --dir "$LISTING/metadata" --output table
  for device in "${DEVICES[@]}"; do
    asc screenshots validate \
      --path "$LISTING/screenshots/$device/en-US" \
      --device-type "$(asc_device_type "$device")" \
      --output table
  done
}

create_app() {
  local apple_id="$1"
  load_asc_credentials
  cd "$ROOT"
  # asc 4.x dropped --public-provider-id from `web apps create`. The web
  # session prompts for the team when the account owns more than one.
  # asc 4.x defaults --auto-rename to true, which silently creates "EST 2" when
  # the App Store name is taken. Fail instead: the name is a product decision.
  asc web apps create \
    --apple-id "$apple_id" \
    --auto-rename false \
    --name "$STORE_NAME" \
    --bundle-id "$BUNDLE_ID" \
    --sku "$SKU" \
    --platform IOS \
    --primary-locale en-US \
    --version "$VERSION" \
    --output json
}

setup_app() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  # Do not pass --bundle-id: app creation already binds it, and re-sending it
  # fails with "The Bundle ID you entered has already been used."
  asc app-setup info set \
    --app "$app_id" \
    --primary-locale en-US \
    --content-rights DOES_NOT_USE_THIRD_PARTY_CONTENT \
    --locale en-US \
    --name "$STORE_NAME" \
    --subtitle "$SUBTITLE" \
    --privacy-policy-url "https://github.com/michellzappa/games/blob/main/PRIVACY.md"
  # Apple models "Games / Puzzle" as a primary category plus subcategories.
  # PUZZLE is not a top-level category, so it cannot be --secondary.
  asc app-setup categories set \
    --app "$app_id" \
    --primary "$(app_json .categories.primary)" \
    --primary-subcategory-one "$(app_json .categories.primarySubcategoryOne)" \
    --primary-subcategory-two "$(app_json .categories.primarySubcategoryTwo)"
  configure_availability "$app_id"
  asc app-setup pricing set \
    --app "$app_id" \
    --free \
    --base-territory USA
  asc age-rating edit --app "$app_id" --all-none

  # Leaderboards attach to a Game Center detail, which a new app record lacks.
  # This is also what makes Game Center recognize the app at runtime.
  if asc game-center details create --app "$app_id" >/dev/null 2>&1; then
    echo "· Game Center detail created"
  else
    echo "· Game Center detail already exists"
  fi

  local count
  count="$(app_json '.leaderboards | length')"
  local i
  for ((i = 0; i < count; i++)); do
    create_leaderboard "$app_id" "$i"
  done
  echo "✓ basic $APP App Store setup complete"
  echo "Next: publish a build, apply privacy declarations, then run upload-screenshots."
}

# Availability is best effort. Apple currently rejects the public-API bootstrap
# for a new app (it demands territory resources the request never named), and
# the asc web-session login fails at Apple's session-info step. Neither is
# something this script can fix, and neither should block categories, pricing,
# age rating, or the leaderboards.
configure_availability() {
  local app_id="$1"
  if ! asc pricing availability create \
    --app "$app_id" \
    --territory USA \
    --available true \
    --available-in-new-territories true >/dev/null 2>&1; then
    echo "⚠ Could not initialize availability through the public API." >&2
    echo "  Set Pricing and Availability in App Store Connect by hand:" >&2
    echo "  free, all territories, China mainland excluded." >&2
    return 0
  fi
  echo "· availability initialized"
  asc app-setup availability edit --app "$app_id" --all-territories --available true
  # China mainland requires a government ISBN for games that carry an in-app
  # purchase. Every app here has the support purchase, so it stays out.
  asc app-setup availability edit --app "$app_id" --territory CHN --available false
}

# One entry of app.json's leaderboards array, by index. The formatter and
# score range are the app's rule: EST ranks centiseconds, SEEP ranks moves.
create_leaderboard() {
  local app_id="$1"
  local index="$2"
  local reference_name vendor_id formatter score_range_start score_range_end
  reference_name="$(app_json ".leaderboards[$index].referenceName")"
  vendor_id="$(app_json ".leaderboards[$index].vendorId")"
  formatter="$(app_json ".leaderboards[$index].formatter")"
  score_range_start="$(app_json ".leaderboards[$index].scoreRangeStart")"
  score_range_end="$(app_json ".leaderboards[$index].scoreRangeEnd")"

  load_asc_credentials
  if asc game-center leaderboards list --app "$app_id" --output json \
    | jq -e --arg vendor "$vendor_id" '.data[]? | select(.attributes.vendorIdentifier == $vendor)' >/dev/null; then
    echo "· Game Center leaderboard exists: $vendor_id"
    return
  fi

  # Do not silently fall back to another formatter: EST submits centiseconds
  # and the legacy ELAPSED_TIME_MILLISECOND uses a different unit.
  if ! asc game-center leaderboards create --help 2>&1 \
    | grep -q -- "$formatter"; then
    echo "✗ Installed asc does not support the $formatter formatter." >&2
    echo "  Upgrade asc before creating the $APP Game Center leaderboards." >&2
    return 1
  fi

  asc game-center leaderboards create \
    --app "$app_id" \
    --reference-name "$reference_name" \
    --vendor-id "$vendor_id" \
    --formatter "$formatter" \
    --score-range-start "$score_range_start" \
    --score-range-end "$score_range_end" \
    --sort ASC \
    --submission-type BEST_SCORE
}

upload_screenshots() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  product_page
  node appstore/metadata.mjs --app "$APP"
  node appstore/validate.mjs --app "$APP"
  for device in "${DEVICES[@]}"; do
    asc screenshots upload \
      --app "$app_id" \
      --version "$VERSION" \
      --path "$LISTING/screenshots/$device" \
      --device-type "$(asc_device_type "$device")" \
      --platform IOS \
      --replace \
      --confirm
  done
}

publish_app() {
  local app_id="$1"
  require_team_id
  load_asc_credentials
  cd "$ROOT"
  node appstore/metadata.mjs --app "$APP"
  local build_number
  build_number="$(project_build_number)"
  [ -n "$build_number" ] || { echo "Could not read CURRENT_PROJECT_VERSION from project.yml"; exit 1; }
  echo "· publishing $VERSION build $build_number"

  asc publish appstore \
    --app "$app_id" \
    --project EST.xcodeproj \
    --scheme "$SCHEME" \
    --version "$VERSION" \
    --build-number "$build_number" \
    --metadata-dir "$LISTING/metadata" \
    --clean \
    --wait \
    --archive-xcodebuild-flag "DEVELOPMENT_TEAM=$TEAM_ID"

  local version_id
  version_id="$(asc versions list --app "$app_id" --version "$VERSION" --platform IOS --output json | jq -r '.data[0].id // empty')"
  [ -n "$version_id" ] || { echo "Could not find App Store version $VERSION after publishing"; exit 1; }
  asc versions update \
    --version-id "$version_id" \
    --copyright "2026 Michell Zappa"
}

submit_app() {
  local app_id="$1"
  load_asc_credentials
  cd "$ROOT"
  asc validate --app "$app_id" --version "$VERSION" --platform IOS --output table
  local build_id
  build_id="$(asc builds info --app "$app_id" --latest --version "$VERSION" --platform IOS --output json | jq -r '.data.id // empty')"
  [ -n "$build_id" ] || { echo "No processed build found for $VERSION"; exit 1; }
  asc review submit \
    --app "$app_id" \
    --version "$VERSION" \
    --build-id "$build_id" \
    --confirm
}

review_details() {
  local app_id="$1"
  local first_name="${EST_REVIEW_FIRST_NAME:-Michell}"
  local last_name="${EST_REVIEW_LAST_NAME:-Zappa}"
  local contact_email="${EST_REVIEW_EMAIL:-}"
  local contact_phone="${EST_REVIEW_PHONE:-}"
  # macOS ships bash 3.2, where "${array[@]}" on an empty array trips set -u.
  # The ${a[@]+"${a[@]}"} form expands to nothing instead of failing, which
  # matters because the phone number is optional.
  local -a contact_args=()
  [ -n "$contact_email" ] || {
    echo "Set EST_REVIEW_EMAIL to the App Review contact email before running review-details"
    exit 1
  }
  # Apple requires contactPhone: "You must provide a value for the attribute
  # 'contactPhone' with this request". Fail here rather than at the API.
  [ -n "$contact_phone" ] || {
    echo "Set EST_REVIEW_PHONE to the App Review contact phone before running review-details"
    exit 1
  }
  contact_args+=(--contact-phone "$contact_phone")

  load_asc_credentials
  cd "$ROOT"
  local version_id
  version_id="$(asc versions list --app "$app_id" --version "$VERSION" --platform IOS --output json | jq -r '.data[0].id // empty')"
  [ -n "$version_id" ] || { echo "Could not find App Store version $VERSION"; exit 1; }

  local notes
  notes="$(<"$LISTING/review-notes.txt")"
  local details_json
  local details_id=""
  if details_json="$(asc review details-for-version --version-id "$version_id" --output json 2>/dev/null)"; then
    details_id="$(printf '%s' "$details_json" | jq -r '.data.id // empty')"
  fi

  if [ -n "$details_id" ]; then
    asc review details-update \
      --id "$details_id" \
      --demo-account-required false \
      --contact-first-name "$first_name" \
      --contact-last-name "$last_name" \
      --contact-email "$contact_email" \
      ${contact_args[@]+"${contact_args[@]}"} \
      --notes "$notes"
  else
    # No app here needs an account. Without this, the created record comes back with
    # demoAccountRequired=true and App Review expects credentials.
    asc review details-create \
      --version-id "$version_id" \
      --demo-account-required false \
      --contact-first-name "$first_name" \
      --contact-last-name "$last_name" \
      --contact-email "$contact_email" \
      ${contact_args[@]+"${contact_args[@]}"} \
      --notes "$notes"
  fi
}

command="${1:-}"
case "$command" in
  prepare) prepare ;;
  create)
    [ "$#" -eq 2 ] || { echo "usage: $0 create <APPLE_ID>"; exit 1; }
    create_app "$2"
    ;;
  product-page)
    [ "$#" -eq 1 ] || { echo "usage: $0 product-page"; exit 1; }
    product_page
    ;;
  setup|upload-screenshots|publish|review-details|submit)
    app_id="${2:-$DEFAULT_APP_ID}"
    [ -n "$app_id" ] || { echo "usage: $0 $APP $command <APP_ID> (or set appId in appstore/$APP/app.json)"; exit 1; }
    case "$command" in
      setup) setup_app "$app_id" ;;
      upload-screenshots) upload_screenshots "$app_id" ;;
      publish) publish_app "$app_id" ;;
      review-details) review_details "$app_id" ;;
      submit) submit_app "$app_id" ;;
    esac
    ;;
  *) usage; exit 1 ;;
esac
