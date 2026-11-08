#!/bin/zsh
set -euo pipefail

workflow=".github/workflows/release.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "announcement: $1" >&2; exit 1; }

awk '
  /- name: Attach the zip and the disk image to the release/ { found = 1; next }
  found && /^ +run: \|$/ { body = 1; match($0, /^ +/); indent = RLENGTH + 2; next }
  body && /^ *$/ { exit }
  body { print substr($0, indent + 1) }
' "$workflow" > "$work/step.sh"
[ -s "$work/step.sh" ] || fail "the step was not found"

mkdir "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/bin/sh
echo "$*" >> "$GH_CALLS"
[ "$1 $2" = "release view" ] && echo "$GH_IS_DRAFT"
exit 0
STUB
chmod +x "$work/bin/gh"

run_step() {
  : > "$work/output"
  : > "$work/calls"
  TAG=v1.2.3 ZIP=a.zip DMG=a.dmg GH_IS_DRAFT="$1" GH_CALLS="$work/calls" \
    GITHUB_OUTPUT="$work/output" PATH="$work/bin:$PATH" bash "$work/step.sh" > /dev/null 2>&1
}

run_step true
grep -qx 'attached=true' "$work/output" || fail "a draft did not take its files"
grep -qx 'published=false' "$work/output" || fail "a draft reads as published"

run_step false
grep -qx 'attached=false' "$work/output" || fail "a published release was offered files"
grep -qx 'published=true' "$work/output" || fail "a published release does not read as published"
if grep -q 'release upload' "$work/calls"; then fail "a published release was uploaded to"; fi

condition="$(grep -A1 -E '^ +- name: Send GitHub Release to Discord' "$workflow" | tail -1)"
print -r -- "$condition" | grep -qF "steps.publish.outcome == 'success'" \
  || fail "the run that publishes does not announce"
print -r -- "$condition" | grep -qF "steps.assets.outputs.published == 'true'" \
  || fail "a rerun after a failed announcement has no way to announce"
print -r -- "$condition" | grep -qF "github.event_name == 'push'" \
  || fail "a run started by hand announces"

grep -qE 'is already published, and a published release cannot be replaced' "$workflow" \
  || fail "a full rerun no longer stops at the changelog job, so it would announce again"

echo "announcement: the run that publishes announces, and a rerun over a published release can finish it."
