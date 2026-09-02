#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64

APP=OLEDGuard.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/OLEDGuard "$APP/Contents/MacOS/OLEDGuard"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Prefer a real signing identity over ad-hoc (`-sign -`): ad-hoc signatures
# are derived from the binary's own hash, so they change on every rebuild
# and macOS silently drops any previously-granted Input Monitoring
# permission (see docs/adr/0003 and issue #3). A Developer ID or even a
# free "Apple Development" identity has a stable Team ID, so the grant
# survives rebuilds/updates. Falls back to ad-hoc if neither is installed
# (e.g. on CI), matching the previous behavior.
# The `|| true` on the grep stage matters: under `set -eo pipefail`, grep's
# exit 1 on "no match" (the normal case on CI, which has no identity
# installed) would otherwise kill the script before it reaches the ad-hoc
# fallback below.
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | { grep -o '"Developer ID Application:[^"]*"\|"Apple Development:[^"]*"' || true; } \
    | head -1 | tr -d '"')"

if [ -z "$SIGN_IDENTITY" ]; then
    echo "No Developer ID / Apple Development signing identity found — using ad-hoc signing."
    echo "Ad-hoc signatures change on every rebuild, so Input Monitoring permission will"
    echo "need re-granting after each update (delete the old entry in System Settings >"
    echo "Privacy & Security > Input Monitoring first if re-enabling it doesn't work)."
    SIGN_IDENTITY="-"
else
    echo "Signing with: $SIGN_IDENTITY"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
echo "First launch: System Settings > Privacy & Security > Input Monitoring > enable OLED Guard"
