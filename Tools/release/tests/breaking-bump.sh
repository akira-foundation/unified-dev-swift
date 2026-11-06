#!/bin/zsh
set -euo pipefail

real_config="${1:-cliff.toml}"
real_config="${real_config:A}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

command -v git-cliff >/dev/null || { echo "breaking-bump: git-cliff is not installed" >&2; exit 1; }

export GIT_AUTHOR_NAME=release-test GIT_AUTHOR_EMAIL=release-test@example.invalid
export GIT_COMMITTER_NAME=release-test GIT_COMMITTER_EMAIL=release-test@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

unreleased_434=$'feat(composer)!: show the agent account in the model menu and choose it per project (#434)\n\n* feat(agent)!: run every workspace and chat of a project on its account\n\nAn agent account is now chosen per project only.\n\nBREAKING CHANGE: changes the behaviour #374 introduced. Workspace account\nchoices are deleted by the migration, and the migrated database is refused\nby older builds.'

repository_with() {
  local repo
  repo="$(mktemp -d "$work/$1.XXXXXX")"
  shift
  git init -q -b main "$repo"
  git -C "$repo" commit -q --allow-empty -m "feat: the first release"
  git -C "$repo" tag v1.1.3
  local message
  for message in "$@"; do
    git -C "$repo" commit -q --allow-empty -m "$message"
  done
  print -r -- "$repo"
}

bumped() {
  git-cliff --config "$1" --repository "$2" --use-branch-tags --bumped-version 2>/dev/null
}

notes() {
  git-cliff --config "$1" --repository "$2" --use-branch-tags --unreleased --strip all 2>/dev/null
}

section_of() {
  awk -v wanted="$2" '
    /^### / { group = substr($0, 5); next }
    index($0, wanted) { print group; exit }
  ' <<< "$1"
}

verdict() {
  local config="$1" repo version text

  repo="$(repository_with only-434 "$unreleased_434")"
  version="$(bumped "$config" "$repo")"
  [ "$version" = v1.2.0 ] \
    || { echo "the #434 commit, which undid work no release carried, bumps to ${version} rather than v1.2.0"; return 1; }
  text="$(notes "$config" "$repo")"
  [ "$(section_of "$text" "choose it per project (#434)")" = Features ] \
    || { echo "the #434 commit is not listed under Features"; return 1; }
  ! grep -q '^### Breaking Changes' <<< "$text" \
    || { echo "the notes keep a Breaking Changes section for the #434 commit"; return 1; }

  repo="$(repository_with bang "fix: an ordinary fix" "feat!: drop the old settings file")"
  version="$(bumped "$config" "$repo")"
  [ "$version" = v2.0.0 ] \
    || { echo "a feat! on 1.x bumps to ${version} rather than v2.0.0"; return 1; }
  text="$(notes "$config" "$repo")"
  [ "$(section_of "$text" "Drop the old settings file")" = "Breaking Changes" ] \
    || { echo "a feat! is not listed under Breaking Changes"; return 1; }

  repo="$(repository_with footer $'feat(composer): show the account\n\nBREAKING CHANGE: the account moves to the project.')"
  version="$(bumped "$config" "$repo")"
  [ "$version" = v2.0.0 ] \
    || { echo "a BREAKING CHANGE footer on 1.x bumps to ${version} rather than v2.0.0"; return 1; }

  repo="$(repository_with both "$unreleased_434" "feat!: drop the old settings file")"
  version="$(bumped "$config" "$repo")"
  [ "$version" = v2.0.0 ] \
    || { echo "the #434 exception hides a real break beside it: ${version}"; return 1; }
}

without_preprocessors() {
  awk '
    /^commit_preprocessors = \[/ { skipping = 1; next }
    skipping && /^\]/ { skipping = 0; next }
    !skipping { print }
  ' "$1"
}

broadened() {
  sed -E "s/^(  \{ pattern = ')\\^feat.*$/\1^([a-z]+(\\\\([^)]*\\\\))?)!:', replace = \"\$1:\" },/" "$1"
}

expect_refused() {
  local name="$1" broken="$work/$1.toml"
  shift
  "$@" "$real_config" > "$broken"
  if verdict "$broken" > /dev/null; then
    echo "breaking-bump: did not notice: $name" >&2
    exit 1
  fi
}

verdict "$real_config" || { echo "breaking-bump: failed" >&2; exit 1; }

expect_refused "no exception for #434" without_preprocessors
expect_refused "every breaking commit bumps the minor" broadened

echo "breaking-bump: only the #434 commit is excused from the major; any other break on 1.x still bumps to 2.0.0."
