#!/bin/zsh
# Runs the browser scripts in a real page.
#
# `BrowserAgentScript` and `BrowserPageScript` are JavaScript, and until this existed nothing in
# this repository executed a character of them. `Tests/CoreTests` depends on `Core` alone by
# design and has no WebKit, and the package `Tools/test-core.sh` writes has no app target at all,
# so the seven bodies were held by structural invariants over their source and by nothing that
# ran them. The whole of issue 200 is that gap.
#
# So this is a second test target, `Tests/BrowserScriptTests`, which links WebKit, loads fixture
# HTML into an offscreen `WKWebView` and asserts what each script answers. It mirrors the core
# into a throwaway package the same way `test-core.sh` does, and for the same reason: `swift test`
# on the real package builds `Sources/UnifiedDev` too, so one broken view would stop these from
# running.
#
#   ./Tools/test-browser-scripts.sh                 run everything, which is also `make test-browser`
#   ./Tools/test-browser-scripts.sh Secrecy         run one suite by filter
#   ./Tools/test-browser-scripts.sh Secrecy Naming  run several (each argument is its own --filter)
#   UD_TEST_RUNS=5 ./Tools/test-browser-scripts.sh   run the whole thing five times, for flakes
#
# Environment:
#   UD_TEST_ID          stable name for the work and build directories, so repeated runs by the
#                       same caller stay incremental
#   UD_TEST_RUNS        how many times to run the suite (default 1)
#   UD_TEST_SWIFT_ARGS  extra flags for `swift test`, split on spaces. The same door
#                       `test-core.sh` has, and nothing passes through it yet: the nightly
#                       workflow's sanitiser and coverage runs still name only that script
#
# `--no-parallel`, and that is the whole of the serialisation. `.serialized` on a suite orders the
# tests inside it and nothing more, so eight of them were still scheduled against each other, and
# `@MainActor` does not stop that: a test suspended in the poll that waits for a page to load
# hands the main actor to the next one, and several `WKWebView`s then load at once. On the three
# cores a `macos-26` runner has, that is how a page takes longer to settle than the ten seconds
# the fixture waits for it, and the wait fails hard rather than warning. One page at a time
# costs a few seconds and removes the whole question.
#
# This needs a window server session. A `WKWebView` here draws nothing and opens no window, but it
# does start a web content process, and that process wants the session a logged-in Mac has. CI runs
# it on the `macos-26` runner for that reason rather than on the Linux one that holds the lint job.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
TMP="${TMPDIR:-/tmp}"
ID="${UD_TEST_ID:-$$}"

# Per-invocation, because two of these at once would otherwise share one build database and
# corrupt each other. Both go when this exits unless the caller named the run, which is what
# makes a repeated run incremental; see the longer version of this paragraph in test-core.sh.
WORK="$TMP/unifieddev-browser-tests-$ID"
SCRATCH="$TMP/unifieddev-browser-build-$ID"

if [[ -z "${UD_TEST_ID:-}" ]]; then
  trap 'rm -rf "$WORK" "$SCRATCH"' EXIT INT TERM HUP
fi

# What a run killed outright left behind, which no trap can cover. A day, so a run still going on
# somebody else's terminal is never swept out from under them.
find "$TMP" -maxdepth 1 \( -name 'unifieddev-browser-build-*' -o -name 'unifieddev-browser-tests-*' \) \
  -mtime +1 -print0 2>/dev/null | xargs -0 -n 20 rm -rf 2>/dev/null || true

rm -rf "$WORK"
mkdir -p "$WORK/Sources" "$WORK/Tests"
ln -sfn "$ROOT/Sources/Core" "$WORK/Sources/Core"
ln -sfn "$ROOT/Tests/BrowserScriptTests" "$WORK/Tests/BrowserScriptTests"

cat > "$WORK/Package.swift" <<'EOF'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrowserScriptsOnly",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Core", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "BrowserScriptTests",
            dependencies: ["Core"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
EOF

filters=()
for name in "$@"; do
  filters+=(--filter "$name")
done

extra=(${=UD_TEST_SWIFT_ARGS:-})

cd "$WORK"

runs="${UD_TEST_RUNS:-1}"
failed=0
for run in $(seq 1 "$runs"); do
  if [[ "$runs" -gt 1 ]]; then
    print -r -- "===> run $run of $runs"
  fi
  if ! swift test --no-parallel --scratch-path "$SCRATCH" "${extra[@]}" "${filters[@]}"; then
    failed=$((failed + 1))
  fi
done

if [[ "$failed" -gt 0 ]]; then
  print -r -- "===> $failed of $runs runs failed"
  exit 1
fi
