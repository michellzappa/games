#!/bin/zsh
# Archive a Release build on the Mac mini with its older Xcode, because App
# Store Connect refuses builds from a newer Xcode it does not support yet.
# See "Toolchain for App Store builds" in AGENTS.md.
#
# Run from another Mac, in the macOS Terminal app (the keychain unlock needs
# a real password prompt):
#   ssh -4 -t mini4p.local '~/Dev/_/ios-est/scripts/mini-archive.sh EST'
#
# The unlock and the archive must run in one SSH session: each session has
# its own keychain lock, and codesign fails with errSecInternalComponent.
set -euo pipefail

scheme="${1:-EST}"
cd ~/Dev/_/ios-est

# The mini regenerates the project, so its copy of the generated file always
# differs from the repo's and would block the pull.
git checkout -- EST.xcodeproj/project.pbxproj
git pull --ff-only -q
/opt/homebrew/bin/xcodegen generate >/dev/null
git log --oneline -1

security unlock-keychain ~/Library/Keychains/login.keychain-db

archive="build/$scheme.xcarchive"
rm -rf "$archive"
xcodebuild -project EST.xcodeproj -scheme "$scheme" -configuration Release \
  -destination generic/platform=iOS -archivePath "$archive" archive \
  DEVELOPMENT_TEAM=992N457T8D 2>&1 | grep -E "errSec|error:|ARCHIVE"

plist="$archive/Products/Applications/$scheme.app/Info.plist"
echo "$scheme $(plutil -extract CFBundleShortVersionString raw "$plist") build $(plutil -extract CFBundleVersion raw "$plist"), Xcode $(plutil -extract DTXcode raw "$plist")"
