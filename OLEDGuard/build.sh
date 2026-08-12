#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=OLEDGuard.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/OLEDGuard "$APP/Contents/MacOS/OLEDGuard"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "First launch: System Settings > Privacy & Security > Input Monitoring > enable OLED Guard"
