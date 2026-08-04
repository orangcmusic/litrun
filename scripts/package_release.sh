#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")"
APP="$ROOT/build/LitRun!.app"
FAN_TOOL="$APP/Contents/Resources/lid-run-switch-fanctl"
DIST="$ROOT/dist"
ZIP_NAME="LitRun-v$VERSION-macOS13-universal.zip"
ZIP_PATH="$DIST/$ZIP_NAME"
DMG_NAME="LitRun-v$VERSION-macOS13-universal.dmg"
DMG_PATH="$DIST/$DMG_NAME"
VERIFY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lidrun-package-verify.XXXXXX")"
ZIP_TMP_PATH="$VERIFY_ROOT/$ZIP_NAME"
ZIP_CHECKSUM_TMP="$VERIFY_ROOT/$ZIP_NAME.sha256"
DMG_TMP_PATH="$VERIFY_ROOT/$DMG_NAME"
DMG_CHECKSUM_TMP="$VERIFY_ROOT/$DMG_NAME.sha256"
PACKAGE_ROOT="$VERIFY_ROOT/package"
DMG_ROOT="$VERIFY_ROOT/dmg-root"
DMG_MOUNT_POINT=""

cleanup() {
  if [ -n "$DMG_MOUNT_POINT" ]; then
    /usr/bin/hdiutil detach "$DMG_MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$VERIFY_ROOT"
}
trap cleanup EXIT

RUN_LIVE_TESTS="${RUN_LIVE_TESTS:-0}" "$ROOT/scripts/test.sh"
"$ROOT/scripts/build.sh"

if [ "${RUN_LAUNCH_SMOKE:-0}" = "1" ]; then
  before_power="$(/usr/bin/pmset -g custom)"
  before_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"

  for _ in 1 2 3; do
    /usr/bin/open -n "$APP"
    /bin/sleep 1
    /usr/bin/osascript -e 'tell application id "io.github.achengbatian.lidrunswitch" to quit'
    /bin/sleep 1
  done

  after_power="$(/usr/bin/pmset -g custom)"
  after_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"
  [ "$before_power" = "$after_power" ]
  [ "$before_disabled" = "$after_disabled" ]
fi

mkdir -p "$DIST"
/bin/mkdir -p "$PACKAGE_ROOT"
/usr/bin/ditto "$APP" "$PACKAGE_ROOT/LitRun!.app"
/usr/bin/find "$PACKAGE_ROOT" -exec /usr/bin/touch -t 200001010000 {} +
(
  cd "$PACKAGE_ROOT"
  TZ=UTC /usr/bin/zip -qry -X "$ZIP_TMP_PATH" "LitRun!.app"
)

if /usr/bin/unzip -l "$ZIP_TMP_PATH" | /usr/bin/grep -E '__MACOSX|/\._' >/dev/null; then
  echo "Archive contains AppleDouble metadata" >&2
  exit 1
fi

(
  cd "$VERIFY_ROOT"
  /usr/bin/shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
  /usr/bin/shasum -a 256 -c "$ZIP_NAME.sha256"
)

/usr/bin/unzip -tq "$ZIP_TMP_PATH"
/usr/bin/unzip -q "$ZIP_TMP_PATH" -d "$VERIFY_ROOT"
ARCHIVE_APP="$VERIFY_ROOT/LitRun!.app"
ARCHIVE_FAN_TOOL="$ARCHIVE_APP/Contents/Resources/lid-run-switch-fanctl"

for candidate in "$APP" "$ARCHIVE_APP"; do
  candidate_fan="$candidate/Contents/Resources/lid-run-switch-fanctl"
  candidate_icon="$candidate/Contents/Resources/AppIcon.icns"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$candidate"
  /usr/bin/codesign --verify --strict --verbose=2 "$candidate_fan"
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist")" = \
    "io.github.achengbatian.lidrunswitch" ]
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$candidate/Contents/Info.plist")" = \
    "$VERSION" ]
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$candidate/Contents/Info.plist")" = \
    "LitRun!" ]
  [ -f "$candidate/Contents/Resources/en.lproj/InfoPlist.strings" ]
  [ -f "$candidate/Contents/Resources/zh-Hans.lproj/InfoPlist.strings" ]
  [ "$(/usr/bin/sips -g pixelWidth "$candidate_icon" |
    /usr/bin/awk '$1 == "pixelWidth:" { print $2 }')" = "1024" ]
  [ "$(/usr/bin/sips -g pixelHeight "$candidate_icon" |
    /usr/bin/awk '$1 == "pixelHeight:" { print $2 }')" = "1024" ]
  /usr/bin/lipo -archs "$candidate/Contents/MacOS/LidRunSwitch" | /usr/bin/grep -q arm64
  /usr/bin/lipo -archs "$candidate/Contents/MacOS/LidRunSwitch" | /usr/bin/grep -q x86_64
  /usr/bin/lipo -archs "$candidate_fan" | /usr/bin/grep -q arm64
  /usr/bin/lipo -archs "$candidate_fan" | /usr/bin/grep -q x86_64
  [ "$("$candidate_fan" version)" = "3" ]
  [ "$(/bin/sh "$candidate/Contents/Resources/lid-run-switch-helper.sh" version)" = "9" ]
done

for binary in \
  "$APP/Contents/MacOS/LidRunSwitch" \
  "$FAN_TOOL" \
  "$ARCHIVE_APP/Contents/MacOS/LidRunSwitch" \
  "$ARCHIVE_FAN_TOOL"; do
  min_versions="$(/usr/bin/vtool -show-build "$binary" |
    /usr/bin/awk '$1 == "minos" { print $2 }' |
    /usr/bin/sort -u)"
  [ "$min_versions" = "13.0" ]
done

[ "$(/usr/bin/shasum -a 256 "$APP/Contents/MacOS/LidRunSwitch" | /usr/bin/awk '{print $1}')" = \
  "$(/usr/bin/shasum -a 256 "$ARCHIVE_APP/Contents/MacOS/LidRunSwitch" | /usr/bin/awk '{print $1}')" ]
[ "$(/usr/bin/shasum -a 256 "$FAN_TOOL" | /usr/bin/awk '{print $1}')" = \
  "$(/usr/bin/shasum -a 256 "$ARCHIVE_FAN_TOOL" | /usr/bin/awk '{print $1}')" ]

/bin/mkdir -p "$DMG_ROOT"
/usr/bin/ditto "$APP" "$DMG_ROOT/LitRun!.app"
/bin/ln -s /Applications "$DMG_ROOT/Applications"
/usr/bin/find "$DMG_ROOT/LitRun!.app" -exec /usr/bin/touch -t 200001010000 {} +
/usr/bin/hdiutil create \
  -ov \
  -format UDZO \
  -srcfolder "$DMG_ROOT" \
  -volname "LitRun! 安装" \
  "$DMG_TMP_PATH" >/dev/null
/usr/bin/hdiutil verify "$DMG_TMP_PATH" >/dev/null

DMG_ATTACH_OUTPUT="$(/usr/bin/hdiutil attach -readonly -nobrowse "$DMG_TMP_PATH")"
DMG_MOUNT_POINT="$(printf '%s\n' "$DMG_ATTACH_OUTPUT" | /usr/bin/awk '
  index($0, "/Volumes/") {
    print substr($0, index($0, "/Volumes/"))
    exit
  }
')"
[ -n "$DMG_MOUNT_POINT" ]
[ -d "$DMG_MOUNT_POINT/LitRun!.app" ]
[ -L "$DMG_MOUNT_POINT/Applications" ]
[ "$(/usr/bin/readlink "$DMG_MOUNT_POINT/Applications")" = "/Applications" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$DMG_MOUNT_POINT/LitRun!.app/Contents/Info.plist")" = "$VERSION" ]
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DMG_MOUNT_POINT/LitRun!.app"
/usr/bin/hdiutil detach "$DMG_MOUNT_POINT" >/dev/null
DMG_MOUNT_POINT=""

(
  cd "$VERIFY_ROOT"
  /usr/bin/shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  /usr/bin/shasum -a 256 -c "$DMG_NAME.sha256"
)

/bin/mv -f "$ZIP_TMP_PATH" "$ZIP_PATH"
/bin/mv -f "$ZIP_CHECKSUM_TMP" "$ZIP_PATH.sha256"
/bin/mv -f "$DMG_TMP_PATH" "$DMG_PATH"
/bin/mv -f "$DMG_CHECKSUM_TMP" "$DMG_PATH.sha256"

if [ -n "${RELEASE_COPY_DIR:-}" ]; then
  /bin/mkdir -p "$RELEASE_COPY_DIR"
  /bin/cp -p \
    "$ZIP_PATH" "$ZIP_PATH.sha256" \
    "$DMG_PATH" "$DMG_PATH.sha256" \
    "$RELEASE_COPY_DIR/"
  (
    cd "$RELEASE_COPY_DIR"
    /usr/bin/shasum -a 256 -c "$ZIP_NAME.sha256"
    /usr/bin/shasum -a 256 -c "$DMG_NAME.sha256"
  )
  echo "$RELEASE_COPY_DIR/$ZIP_NAME"
  echo "$RELEASE_COPY_DIR/$ZIP_NAME.sha256"
  echo "$RELEASE_COPY_DIR/$DMG_NAME"
  echo "$RELEASE_COPY_DIR/$DMG_NAME.sha256"
fi

echo "$ZIP_PATH"
echo "$ZIP_PATH.sha256"
echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
