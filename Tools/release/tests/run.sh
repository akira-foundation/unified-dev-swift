#!/bin/zsh
# Everything in the release path that can be checked without a certificate, a
# notarisation credential.
#
#   Tools/release/tests/run.sh
#
# What it does not cover, and cannot: signing, notarising, stapling, and the
# upload. Those need secrets that exist only on the release runner.

set -euo pipefail
cd "$(dirname "$0")/../../.."

TOOLS=Tools/release
WORK="$(mktemp -d -t unifieddev-release-tests)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "  ok  $1"; }
no() { FAILED=$((FAILED + 1)); echo "  NO  $1" >&2; }

expect_equal() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1: expected '$3', got '$2'"; fi
}

expect_fails() {
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then no "$label: it succeeded and should not have"; else ok "$label"; fi
}

echo "version.sh"

eval "$("$TOOLS/version.sh" v1.4.0)"
expect_equal "a plain tag is a stable release" "$version $channel $prerelease" "1.4.0 stable 0"
[ "$build" -gt 0 ] && ok "the build number is the commit count" || no "the build number is $build"

eval "$("$TOOLS/version.sh" v1.4.0-beta.1)"
expect_equal "a semver prerelease tag goes to the beta channel" "$version $channel $prerelease" "1.4.0-beta.1 beta 1"

eval "$("$TOOLS/version.sh" 2.0)"
expect_equal "the leading v is optional" "$version" "2.0"

eval "$("$TOOLS/version.sh" v1.4.0.9)"
expect_equal "four components are allowed" "$version" "1.4.0.9"

expect_fails "a tag that is not a version is refused" "$TOOLS/version.sh" banana
expect_fails "a tag with a shell metacharacter is refused" "$TOOLS/version.sh" 'v1.0; touch /tmp/unifieddev-owned'
expect_fails "an empty tag is refused" "$TOOLS/version.sh" ""
expect_fails "five components are refused" "$TOOLS/version.sh" v1.2.3.4.5

# Two refs, two counts, and the older one has to be smaller. This is the whole
# reason the build number is a commit count rather than a timestamp.
FIRST="$(git rev-list --max-parents=0 HEAD | head -1)"
eval "$("$TOOLS/version.sh" v1.0.0 "$FIRST")"
FIRST_BUILD=$build
eval "$("$TOOLS/version.sh" v1.0.0 HEAD)"
[ "$build" -gt "$FIRST_BUILD" ] && ok "the build number grows along history" || no "build $build is not above $FIRST_BUILD"


echo "nested-code.sh"

# A bundle shaped like one Sparkle has been embedded into, built out of real
# Mach-O files so the detection is exercised rather than mocked. This is the
# part of signing that is easiest to get quietly wrong and hardest to notice:
# a missed binary passes codesign --verify and is rejected by Apple an hour
# later.
FAKE="$WORK/UnifiedDev.app"
FRAMEWORK="$FAKE/Contents/Frameworks/Sparkle.framework"
mkdir -p "$FAKE/Contents/MacOS" "$FAKE/Contents/Resources/UnifiedDev_UnifiedDev.bundle"
mkdir -p "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc/Contents/MacOS"
mkdir -p "$FRAMEWORK/Versions/B/Updater.app/Contents/MacOS"
cp /bin/echo "$FAKE/Contents/MacOS/UnifiedDev"
cp /bin/echo "$FRAMEWORK/Versions/B/Sparkle"
cp /bin/echo "$FRAMEWORK/Versions/B/Autoupdate"
cp /bin/echo "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
cp /bin/echo "$FRAMEWORK/Versions/B/Updater.app/Contents/MacOS/Updater"
cp /usr/lib/libSystem.B.dylib "$FAKE/Contents/MacOS/libSwiftTerm.dylib" 2>/dev/null ||   cp /bin/echo "$FAKE/Contents/MacOS/libSwiftTerm.dylib"
echo 'a resource, not code' > "$FAKE/Contents/Resources/UnifiedDev_UnifiedDev.bundle/thing.txt"
printf '#!/bin/sh\necho hello\n' > "$FAKE/Contents/Resources/helper.sh"
chmod +x "$FAKE/Contents/Resources/helper.sh"
( cd "$FRAMEWORK/Versions" && ln -s B Current )
( cd "$FRAMEWORK" && ln -s Versions/Current/Updater.app Updater.app )
( cd "$FRAMEWORK" && ln -s Versions/Current/Sparkle Sparkle )

LISTING="$WORK/nested.txt"
"$TOOLS/nested-code.sh" "$FAKE" | sed "s|$FAKE/||" > "$LISTING"

has() { grep -qxF "$1" "$LISTING"; }
lineno() { grep -nxF "$1" "$LISTING" | cut -d: -f1; }

has "Contents/Frameworks/Sparkle.framework" && ok "the framework is listed" || no "the framework is missing"
has "Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"   && ok "Sparkle's loose Autoupdate binary is listed"   || no "Sparkle's loose Autoupdate binary was missed"
has "Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"   && ok "the XPC service is listed" || no "the XPC service is missing"
has "Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"   && ok "the helper app is listed" || no "the helper app is missing"
has "Contents/MacOS/libSwiftTerm.dylib" && ok "a dylib is listed" || no "the dylib is missing"

if grep -q "Versions/Current" "$LISTING"; then
  no "a symlinked alias was listed, so something would be signed twice"
else
  ok "symlinked aliases are left out"
fi

if grep -qxF "Contents/Frameworks/Sparkle.framework/Updater.app" "$LISTING"; then
  no "the framework's top level Updater.app alias was listed"
else
  ok "the framework's top level alias is left out"
fi

if grep -q "helper.sh" "$LISTING"; then
  no "a shell script was listed as code to sign"
else
  ok "an executable that is not Mach-O is left out"
fi

# The whole point of the ordering.
XPC_AT="$(lineno "Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc")"
UPDATER_AT="$(lineno "Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app")"
AUTOUPDATE_AT="$(lineno "Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate")"
FRAMEWORK_AT="$(lineno "Contents/Frameworks/Sparkle.framework")"
if [ "$XPC_AT" -lt "$FRAMEWORK_AT" ] && [ "$UPDATER_AT" -lt "$FRAMEWORK_AT" ] && [ "$AUTOUPDATE_AT" -lt "$FRAMEWORK_AT" ]; then
  ok "everything inside the framework comes before the framework"
else
  no "the framework would be signed before its own contents"
fi

INSTALLER_BIN_AT="$(lineno "Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer")"
if [ "$INSTALLER_BIN_AT" -lt "$XPC_AT" ]; then
  ok "an executable comes before the bundle around it"
else
  no "a bundle would be signed before its own executable"
fi

expect_fails "a path that is not a bundle is refused" "$TOOLS/nested-code.sh" "$WORK/nope.app"


echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
