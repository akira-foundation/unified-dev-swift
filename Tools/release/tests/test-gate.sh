#!/bin/zsh
set -euo pipefail

real_release=".github/workflows/release.yml"
real_test=".github/workflows/test.yml"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

job() {
  awk -v name="$1" '
    $0 == "  " name ":" { inside = 1; print; next }
    inside && /^  [^ #]/ { exit }
    inside { print }
  ' "$2"
}

verdict() {
  local release="$1" test="$2" tests changelog build
  tests="$(job tests "$release")"
  changelog="$(job changelog "$release")"
  build="$(job release "$release")"

  print -r -- "$tests" | grep -qxF '    uses: ./.github/workflows/test.yml' \
    || { echo "release.yml does not run test.yml"; return 1; }
  print -r -- "$tests" | grep -qxF "      ref: \${{ github.event_name == 'push' && github.ref || format('refs/tags/{0}', inputs.tag) }}" \
    || { echo "the tests are not run on the tag being released"; return 1; }

  print -r -- "$changelog" | grep -qxE '    needs: (tests|\[(.*, )?tests(, .*)?\])' \
    || { echo "the draft is created without waiting for the tests"; return 1; }
  print -r -- "$changelog" | grep -qE '^ +gh release create ' \
    || { echo "the draft is no longer created in the changelog job"; return 1; }
  [ "$(grep -cE '^ +gh release create ' "$release")" = 1 ] \
    || { echo "a release is created somewhere other than the changelog job"; return 1; }
  if print -r -- "$changelog" | grep -qE '^    if: .*(always\(\)|!cancelled\(\)|failure\(\))'; then
    echo "the changelog job runs whatever the tests answered"
    return 1
  fi

  print -r -- "$build" | grep -qxE '    needs: \[(.*, )?tests(, .*)?\]' \
    || { echo "the release is built without waiting for the tests"; return 1; }
  print -r -- "$build" | grep -qE "^    if: .*needs\.tests\.result == 'success'" \
    || { echo "the release is built after the tests failed"; return 1; }
  print -r -- "$build" | grep -qE '^ +gh release edit .*--draft=false' \
    || { echo "the release is no longer published in the release job"; return 1; }

  awk '/^  workflow_call:$/ { on = 1; next } on && /^  [^ ]/ { exit } on' "$test" \
    | grep -qxF '      ref:' || { echo "test.yml takes no ref from its caller"; return 1; }
  [ "$(grep -cE '^ +- uses: actions/checkout@' "$test")" = "$(grep -cxF '          ref: ${{ inputs.ref }}' "$test")" ] \
    || { echo "a job in test.yml checks out something other than the ref it was called with"; return 1; }
}

expect_refused() {
  local name="$1" which="$2"
  shift 2
  cp "$real_release" "$work/release.yml"
  cp "$real_test" "$work/test.yml"
  "$@" "$work/$which" > "$work/broken"
  mv "$work/broken" "$work/$which"
  if verdict "$work/release.yml" "$work/test.yml" > /dev/null; then
    echo "test-gate: did not notice: $name" >&2
    exit 1
  fi
}

verdict "$real_release" "$real_test" || { echo "test-gate: failed" >&2; exit 1; }

expect_refused "changelog without the tests" release.yml sed -E '/^    needs: tests$/d'
expect_refused "changelog run whatever happened" release.yml \
  sed -E "s/^    if: github.event_name == 'push'$/    if: always() \&\& github.event_name == 'push'/"
expect_refused "release only after the changelog" release.yml sed -E 's/^    needs: \[tests, changelog\]$/    needs: changelog/'
expect_refused "release after failed tests" release.yml sed -E "s/ \&\& needs\.tests\.result == 'success'//"
expect_refused "tests on the branch tip" release.yml sed -E 's/^      ref: \$\{\{ github.event_name.*$/      ref: ${{ github.ref }}/'
expect_refused "tests from another workflow" release.yml sed -E 's|uses: ./.github/workflows/test.yml|uses: ./.github/workflows/nightly.yml|'
expect_refused "a second release created" release.yml \
  awk '{ print } /^ +gh release edit .*--draft=false/ { print "          gh release create \"$TAG\"" }'
expect_refused "no ref from the caller" test.yml sed -E '/^      ref:$/d'
expect_refused "a checkout of the default ref" test.yml awk '/ref: \$\{\{ inputs.ref \}\}/ && !done { done = 1; next } { print }'

echo "test-gate: nothing is drafted, built or published until lint, build and test pass on the tagged commit."
