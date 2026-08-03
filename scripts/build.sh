#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
APP_NAME="LitRun!"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE_NAME="LidRunSwitch"
TARGET_VERSION="13.0"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lidrun-build.XXXXXX")"
trap '/bin/rm -rf "$TEMP_ROOT"' EXIT

SOURCES=("$ROOT"/*.swift)
ARCHS=(arm64 x86_64)
if [ -n "${LIDRUN_ARCHS:-}" ]; then
  read -r -a ARCHS <<< "$LIDRUN_ARCHS"
fi

mkdir -p "$TEMP_ROOT/$APP_NAME.app/Contents/MacOS"
mkdir -p "$TEMP_ROOT/$APP_NAME.app/Contents/Resources"
mkdir -p "$BUILD_DIR"

BINARIES=()
FAN_BINARIES=()
for arch in "${ARCHS[@]}"; do
    binary="$TEMP_ROOT/$EXECUTABLE_NAME-$arch"
  xcrun swiftc -warnings-as-errors -O \
    -target "$arch-apple-macos$TARGET_VERSION" \
    "${SOURCES[@]}" \
    -o "$binary"
    BINARIES+=("$binary")

    fan_binary="$TEMP_ROOT/lid-run-switch-fanctl-$arch"
    xcrun swiftc -warnings-as-errors -O \
      -target "$arch-apple-macos$TARGET_VERSION" \
      "$ROOT/Localization.swift" \
      "$ROOT/FanTelemetry.swift" \
      "$ROOT/FanControlPolicy.swift" \
      "$ROOT/FanControlEngine.swift" \
      "$ROOT/FanHelper/FanControlToolMain.swift" \
      -o "$fan_binary"
    FAN_BINARIES+=("$fan_binary")
done

if [ "${#BINARIES[@]}" -eq 1 ]; then
  /usr/bin/ditto "${BINARIES[0]}" "$TEMP_ROOT/$APP_NAME.app/Contents/MacOS/$EXECUTABLE_NAME"
else
  /usr/bin/lipo -create "${BINARIES[@]}" \
    -output "$TEMP_ROOT/$APP_NAME.app/Contents/MacOS/$EXECUTABLE_NAME"
fi

if [ "${#FAN_BINARIES[@]}" -eq 1 ]; then
  /usr/bin/ditto "${FAN_BINARIES[0]}" \
    "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-fanctl"
else
  /usr/bin/lipo -create "${FAN_BINARIES[@]}" \
    -output "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-fanctl"
fi

/usr/bin/ditto "$ROOT/Info.plist" "$TEMP_ROOT/$APP_NAME.app/Contents/Info.plist"
/usr/bin/ditto "$ROOT/README.txt" "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/README.txt"
/usr/bin/ditto "$ROOT/THIRD_PARTY_NOTICES.md" \
  "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/THIRD_PARTY_NOTICES.md"
/usr/bin/ditto "$ROOT/Resources/lid-run-switch-helper.sh" \
  "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-helper.sh"
/usr/bin/ditto "$ROOT/Resources/en.lproj" \
  "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/en.lproj"
/usr/bin/ditto "$ROOT/Resources/zh-Hans.lproj" \
  "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/zh-Hans.lproj"
/bin/chmod 0755 "$TEMP_ROOT/$APP_NAME.app/Contents/MacOS/$EXECUTABLE_NAME"
/bin/chmod 0755 "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-helper.sh"
/bin/chmod 0755 "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-fanctl"

ICONSET="$TEMP_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in \
  '16 icon_16x16.png' \
  '32 icon_16x16@2x.png' \
  '32 icon_32x32.png' \
  '64 icon_32x32@2x.png' \
  '128 icon_128x128.png' \
  '256 icon_128x128@2x.png' \
  '256 icon_256x256.png' \
  '512 icon_256x256@2x.png' \
  '512 icon_512x512.png' \
  '1024 icon_512x512@2x.png'; do
  size="${spec%% *}"
  name="${spec#* }"
  /usr/bin/sips -z "$size" "$size" "$ROOT/Resources/AppIcon-1024.png" \
    --out "$ICONSET/$name" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" \
  -o "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/AppIcon.icns"

identity="${CODESIGN_IDENTITY:--}"
if [ "$identity" = "-" ]; then
  /usr/bin/codesign --force --sign - \
    "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-fanctl"
  /usr/bin/codesign --force --sign - "$TEMP_ROOT/$APP_NAME.app"
else
  /usr/bin/codesign --force --deep --options runtime --timestamp \
    --sign "$identity" \
    "$TEMP_ROOT/$APP_NAME.app/Contents/Resources/lid-run-switch-fanctl"
  /usr/bin/codesign --force --options runtime --timestamp \
    --sign "$identity" "$TEMP_ROOT/$APP_NAME.app"
fi

/bin/rm -rf "$APP_DIR"
/bin/mv "$TEMP_ROOT/$APP_NAME.app" "$APP_DIR"

/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
/usr/bin/codesign --verify --strict --verbose=2 \
  "$APP_DIR/Contents/Resources/lid-run-switch-fanctl"
/usr/bin/lipo -archs "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
/usr/bin/lipo -archs "$APP_DIR/Contents/Resources/lid-run-switch-fanctl"
[ "$(/usr/bin/sips -g pixelWidth "$APP_DIR/Contents/Resources/AppIcon.icns" |
  /usr/bin/awk '$1 == "pixelWidth:" { print $2 }')" = "1024" ]
[ "$(/usr/bin/sips -g pixelHeight "$APP_DIR/Contents/Resources/AppIcon.icns" |
  /usr/bin/awk '$1 == "pixelHeight:" { print $2 }')" = "1024" ]
[ "$("$APP_DIR/Contents/Resources/lid-run-switch-fanctl" version)" = "3" ]
[ "$(/bin/sh "$APP_DIR/Contents/Resources/lid-run-switch-helper.sh" version)" = "9" ]

echo "$APP_DIR"
