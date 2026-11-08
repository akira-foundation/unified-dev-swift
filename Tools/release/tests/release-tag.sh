#!/bin/zsh
set -euo pipefail

workflow=".github/workflows/release.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

awk '
  /- name: Work out what is being released/ { found = 1; next }
  found && /^ +run: \|$/ { body = 1; match($0, /^ +/); indent = RLENGTH + 2; next }
  body && /^ *$/ { exit }
  body { print substr($0, indent + 1) }
' "$workflow" > "$work/step.sh"
[ -s "$work/step.sh" ] || { echo "release-tag: the step was not found" >&2; exit 1; }

mkdir "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/bin/sh
echo "$*" >> "$GH_CALLS"
echo "$GH_IS_DRAFT"
STUB
chmod +x "$work/bin/gh"

run_step() {
  local event="$1" tag="$2" draft="${3:-true}" pushed=""
  [ "$event" = push ] && pushed="$tag"
  : > "$work/output"
  : > "$work/calls"
  EVENT="$event" PUSHED_TAG="$pushed" INPUT_TAG="$tag" GH_IS_DRAFT="$draft" GH_CALLS="$work/calls" \
    GITHUB_OUTPUT="$work/output" GITHUB_REPOSITORY="owner/repo" PATH="$work/bin:$PATH" \
    bash "$work/step.sh" > /dev/null 2>&1
}

fail() { echo "release-tag: $1" >&2; exit 1; }

for tag in main refs/heads/main v1.2 1.2.3 'v1.2.3;id' 'v1.2.3 ' 'v1.2.3-' '$(id)' ''; do
  if run_step workflow_dispatch "$tag"; then fail "built from '$tag'"; fi
  [ ! -s "$work/calls" ] || fail "asked GitHub about '$tag' before refusing it"
done

for tag in v1.2.3 v1.2.3-rc.1 v10.20.30-beta-2; do
  run_step workflow_dispatch "$tag" || fail "refused '$tag'"
  grep -qx "tag=$tag" "$work/output" || fail "'$tag' did not reach the output"
  grep -q "release view $tag --repo owner/repo" "$work/calls" || fail "'$tag' was not checked against its release"
done

if run_step workflow_dispatch v1.2.3 false; then fail "built a release that is already published"; fi

run_step push v1.2.3 false || fail "a pushed tag was refused for having a published release"
[ ! -s "$work/calls" ] || fail "a pushed tag asked GitHub for a draft"
if run_step push main; then fail "built from a pushed 'main'"; fi

grep -qF 'ref: ${{ needs.target.outputs.sha }}' "$workflow" \
  || fail "the checkout builds something other than the commit that was tested"

echo "release-tag: only a version tag is built, and by hand only one whose release is a draft."
