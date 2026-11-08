#!/bin/zsh
set -euo pipefail

real_workflow=".github/workflows/release.yml"
broken="$(mktemp)"
trap 'rm -f "$broken"' EXIT

line_of() {
  { grep -nE "$1" "$2" || true; } | sed -n "${3:-1}p" | cut -d: -f1
}

verdict() {
  local workflow="$1" created attached published last_announcement
  created="$(line_of '^ +gh release create ' "$workflow")"
  [ -n "$created" ] || { echo "no step creates the release"; return 1; }

  local command
  command="$(awk -v start="$created" 'NR >= start { print; if ($0 !~ /\\$/) exit }' "$workflow")"
  print -r -- "$command" | grep -qE -- '--draft( |$)' \
    || { echo "the release is created published, and a published release takes no files"; return 1; }
  if print -r -- "$command" | grep -q -- '--latest'; then
    echo "a draft cannot be Latest, so Latest is set when it is published"
    return 1
  fi

  attached="$(line_of '^ +gh release upload ' "$workflow")"
  published="$(line_of '^ +gh release edit .*--draft=false' "$workflow")"
  [ -n "$attached" ] || { echo "no step attaches the files"; return 1; }
  [ -n "$published" ] || { echo "no step publishes the draft"; return 1; }
  [ "$attached" -lt "$published" ] || { echo "the release is published before its files are attached"; return 1; }
  sed -n "${published}p" "$workflow" | grep -qF -- '--latest="${LATEST:-false}"' \
    || { echo "publishing leaves Latest to GitHub, which gives it to an older line"; return 1; }
  sed -n "$((attached - 1))p" "$workflow" | grep -q '= true' \
    || { echo "the files are uploaded without checking the release is still a draft"; return 1; }

  local deleted
  deleted="$(line_of '^ +gh release delete ' "$workflow")"
  [ -n "$deleted" ] || { echo "a draft from a failed run is never replaced"; return 1; }
  sed -n "$((deleted - 1))p" "$workflow" | grep -q '= true' \
    || { echo "a release is deleted without checking it is a draft"; return 1; }

  for last_announcement in \
    "$(line_of '^ +- name: Rebuild the landing page' "$workflow" 1)" \
    "$(line_of '^ +- name: Send GitHub Release to Discord' "$workflow" 1)"; do
    [ -n "$last_announcement" ] || { echo "an announcement step is missing"; return 1; }
    [ "$published" -lt "$last_announcement" ] || { echo "the release is announced before it is published"; return 1; }
  done

  [ "$(grep -cE '^ +if curl .*LANDING_DEPLOY_HOOK' "$workflow")" = 1 ] \
    || { echo "the landing page is asked to rebuild more or less than once"; return 1; }

  if grep -E '^ +gh release delete ' "$workflow" | grep -q '|| true'; then
    echo "a failed delete is ignored, and the step then acts on a release it did not check"
    return 1
  fi
}

expect_refused() {
  local name="$1"
  shift
  "$@" "$real_workflow" > "$broken"
  if verdict "$broken" > /dev/null; then
    echo "publish-order: did not notice: $name" >&2
    exit 1
  fi
}

moved_upload_after_publish() {
  awk '
    /^ +gh release upload / { held = $0; next }
    { print }
    /^ +gh release edit .*--draft=false/ { print held }
  ' "$1"
}

second_hook_call() {
  awk '
    { print }
    /^ +if curl .*LANDING_DEPLOY_HOOK/ { print; print "          fi" }
  ' "$1"
}

moved_discord_above_publish() {
  awk '
    FNR == NR { if ($0 ~ /- name: Send GitHub Release to Discord/) found = FNR; next }
    /- name: Publish the release/ { print "      - name: Send GitHub Release to Discord" }
    FNR != found { print }
  ' "$1" "$1"
}

verdict "$real_workflow" || { echo "publish-order: failed" >&2; exit 1; }

expect_refused "hook called twice" second_hook_call
expect_refused "created published" sed -E 's/^( +)--draft \\$/\1--draft=false \\/'
expect_refused "no draft" sed -E '/^ +--draft \\$/d'
expect_refused "no publish" sed -E '/gh release edit .*--draft=false/d'
expect_refused "publish without Latest" sed -E 's/ --latest="\$\{LATEST:-false\}"//'
expect_refused "upload after publish" moved_upload_after_publish
expect_refused "announced before publish" moved_discord_above_publish
expect_refused "delete failure ignored" sed -E 's/^( +gh release delete .*)$/\1 || true/'
expect_refused "Latest created on a draft" sed -E 's/^( +)--draft \\$/\1--draft --latest \\/'
expect_refused "Latest forced on publish" sed -E 's/--latest="\$\{LATEST:-false\}"/--latest=true/'
expect_refused "delete without the draft check" sed -E 's/^( +)if \[ "\$\{is_draft\}" = true \]; then$/\1if : ; then/'
expect_refused "upload without the draft check" sed -E 's/^( +)if \[ "\$is_draft" = true \]; then$/\1if : ; then/'

echo "publish-order: the draft takes its files, then it is published, then it is announced."
