#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/drag2wakeup.app
[ -d "$APP" ] && trash "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/drag2wakeup "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "빌드끝: $APP"
