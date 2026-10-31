#!/bin/zsh
# What Tools/dmg/build.sh produces, checked against a stub bundle rather than a
# release build, so every pull request can afford it.
#
#   zsh Tools/dmg/tests/disk-image.sh
#
# The volume name is the assertion that matters. It reaches dmgbuild as a single
# argument only while it is quoted, and a release run that signed and notarised
# v1.0.0-rc.1 died on the unquoted form with no asset to show for it.

set -euo pipefail
cd "$(dirname "$0")/../../.."

WORK="$(mktemp -d -t unifieddev-dmg-test)"
trap 'hdiutil detach "/Volumes/Unified Dev" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

APP="$WORK/UnifiedDev.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.akira.unifieddev.dmgtest</string>
<key>CFBundleName</key><string>UnifiedDev</string>
<key>CFBundleExecutable</key><string>UnifiedDev</string>
<key>CFBundleShortVersionString</key><string>0.0.0-test</string>
</dict></plist>
PLIST
cp /bin/echo "$APP/Contents/MacOS/UnifiedDev"

OUT="$WORK/out.dmg"
./Tools/dmg/build.sh --app "$APP" --out "$OUT"
[ -f "$OUT" ] || { echo "no disk image at $OUT" >&2; exit 1; }

MOUNT="$(hdiutil attach "$OUT" -nobrowse -readonly | tail -1 | awk -F'\t' '{print $NF}' | sed 's/^ *//')"
trap 'hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
if [ "$MOUNT" != "/Volumes/Unified Dev" ]; then
  echo "the volume is at $MOUNT, so the name reached dmgbuild in pieces" >&2
  exit 1
fi
[ -d "$MOUNT/UnifiedDev.app" ] || { echo "the bundle is not on the volume" >&2; exit 1; }
[ -L "$MOUNT/Applications" ] || { echo "the Applications alias is missing" >&2; exit 1; }

echo "Disk image checks passed"
