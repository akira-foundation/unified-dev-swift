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

job_names() {
  awk '/^jobs:$/ { on = 1; next } on && /^  [^ #]/ { sub(/^  /, ""); sub(/:.*/, ""); print }' "$1" | sort | tr '\n' ' '
}

runs_unconditionally() {
  awk -v wanted="        run: $2" '
    $0 == wanted { found = (previous !~ /^ +if:/); exit }
    { previous = $0 }
    END { exit !found }
  ' "$1"
}

line_of() {
  { grep -nE "$1" "$2" || true; } | head -1 | cut -d: -f1
}

verdict_on_release() {
  local release="$1" target tests changelog build checked published
  target="$(job target "$release")"
  tests="$(job tests "$release")"
  changelog="$(job changelog "$release")"
  build="$(job release "$release")"

  [ "$(job_names "$release")" = "changelog release target tests " ] \
    || { echo "release.yml has a job the gate does not know about"; return 1; }
  grep -qF 'sha="$PUSHED_SHA"' <<< "$target" \
    || { echo "a pushed tag does not test the commit that was pushed"; return 1; }
  grep -qF 'commits/tags/$INPUT_TAG' <<< "$target" \
    || { echo "a run by hand does not pin the commit its tag names"; return 1; }

  grep -qxF '    uses: ./.github/workflows/test.yml' <<< "$tests" \
    || { echo "release.yml does not run test.yml"; return 1; }
  grep -qxF '    needs: target' <<< "$tests" \
    || { echo "the tests start before the commit is pinned"; return 1; }
  grep -qxF '      ref: ${{ needs.target.outputs.sha }}' <<< "$tests" \
    || { echo "the tests are not run on the pinned commit"; return 1; }

  grep -qxF '    needs: tests' <<< "$changelog" \
    || { echo "the draft is created without waiting for the tests"; return 1; }
  grep -qxF "    if: github.event_name == 'push'" <<< "$changelog" \
    || { echo "the changelog job has a condition that can outlive failed tests"; return 1; }

  grep -qxF '    needs: [target, tests, changelog]' <<< "$build" \
    || { echo "the release is built without waiting for the tests"; return 1; }
  grep -qxF "    if: \${{ !cancelled() && needs.tests.result == 'success' && needs.changelog.result != 'failure' }}" <<< "$build" \
    || { echo "the release is built after the tests failed"; return 1; }
  grep -qxF '          ref: ${{ needs.target.outputs.sha }}' <<< "$build" \
    || { echo "the release builds something other than the tested commit"; return 1; }

  [ "$(grep -cE 'gh release create ' "$release")" = 1 ] && grep -qE 'gh release create ' <<< "$changelog" \
    || { echo "a release is created somewhere other than the changelog job"; return 1; }
  if grep -qE 'gh release ' <<< "$target$tests"; then
    echo "a release is touched before the tests have answered"
    return 1
  fi

  checked="$(line_of '^ +- name: Check the tag still names the commit that was tested' "$release")"
  published="$(line_of '^ +gh release edit .*--draft=false' "$release")"
  [ -n "$checked" ] && [ -n "$published" ] && [ "$checked" -lt "$published" ] \
    || { echo "a tag moved after the tests is published anyway"; return 1; }
}

verdict_on_test() {
  local test="$1" name
  [ "$(job_names "$test")" = "build lint test " ] \
    || { echo "test.yml no longer has exactly lint, build and test"; return 1; }
  grep -qxF '      ref:' <<< "$(awk '/^  workflow_call:$/ { on = 1; next } on && /^  [^ ]/ { exit } on' "$test")" \
    || { echo "test.yml takes no ref from its caller"; return 1; }
  [ "$(grep -c 'actions/checkout@' "$test")" = "$(grep -cxF '          ref: ${{ inputs.ref }}' "$test")" ] \
    || { echo "a job in test.yml checks out something other than the ref it was called with"; return 1; }
  grep -qxF '    needs: lint' <<< "$(job test "$test")" \
    || { echo "the test job takes a macOS runner before lint has passed"; return 1; }
  if grep -q 'continue-on-error' "$test"; then
    echo "a failure in test.yml can be ignored"
    return 1
  fi
  if grep -qE '^    if:' "$test"; then
    echo "a job in test.yml can be skipped and still read as passed"
    return 1
  fi

  grep -qF 'PATH="$PWD/swiftlint-bin:$PATH" ./Tools/swiftlint.sh' "$test" \
    || { echo "test.yml no longer runs SwiftLint"; return 1; }
  for name in ./Tools/house-rules.sh 'zsh Tools/release/tests/test-gate.sh' \
    'swift build -Xswiftc -warnings-as-errors' ./Tools/test-core.sh ./Tools/test-browser-scripts.sh; do
    runs_unconditionally "$test" "$name" \
      || { echo "test.yml no longer runs $name on every call"; return 1; }
  done
}

verdict() {
  verdict_on_release "$1" && verdict_on_test "$2"
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
  sed -E "s/^    if: github.event_name == 'push'$/    if: cancelled() || success()/"
expect_refused "release only after the changelog" release.yml sed -E 's/^    needs: \[target, tests, changelog\]$/    needs: changelog/'
expect_refused "release after failed tests" release.yml sed -E "s/ \&\& needs\.tests\.result == 'success'//"
expect_refused "release with a way round the tests" release.yml \
  sed -E "s/needs\.tests\.result == 'success'/needs.tests.result == 'success' || needs.changelog.result == 'skipped'/"
expect_refused "tests on the tag name" release.yml sed -E 's/^      ref: \$\{\{ needs\.target\.outputs\.sha \}\}$/      ref: ${{ github.ref }}/'
expect_refused "build on the tag name" release.yml sed -E 's/^          ref: \$\{\{ needs\.target\.outputs\.sha \}\}$/          ref: refs\/tags\/${{ steps.release.outputs.tag }}/'
expect_refused "tests from another workflow" release.yml sed -E 's|uses: ./.github/workflows/test.yml|uses: ./.github/workflows/nightly.yml|'
expect_refused "a second release created" release.yml \
  awk '{ print } /^ +gh release edit .*--draft=false/ { print "          gh release create \"$TAG\"" }'
expect_refused "a new job around the tests" release.yml \
  awk '/^  changelog:$/ { print "  early:"; print "    runs-on: ubuntu-latest"; print "" } { print }'
expect_refused "published without looking at the tag" release.yml \
  sed -E 's/- name: Check the tag still names the commit that was tested/- name: Look at the tag/'
expect_refused "no ref from the caller" test.yml sed -E '/^      ref:$/d'
expect_refused "a checkout of the default ref" test.yml awk '/ref: \$\{\{ inputs.ref \}\}/ && !done { done = 1; next } { print }'
expect_refused "a checkout written as a name and a uses" test.yml \
  awk '/- uses: actions\/checkout@/ && !done { done = 1; print "      - name: Check out"; sub(/- uses/, "  uses"); print; getline; getline; next } { print }'
expect_refused "test beside lint" test.yml sed -E '/^    needs: lint$/d'
expect_refused "a job that may fail" test.yml awk '{ print } /^  build:$/ { print "    continue-on-error: true" }'
expect_refused "a job skipped on a call" test.yml awk '{ print } /^  build:$/ { print "    if: ${{ !inputs.ref }}" }'
expect_refused "the build removed" test.yml \
  awk '/^  build:$/ { skip = 1; next } /^  # The two test suites/ { skip = 0 } !skip { print }'
expect_refused "the suite skipped" test.yml \
  awk '/run: \.\/Tools\/test-core\.sh$/ { print "        if: false" } { print }'
expect_refused "the suite excused" test.yml sed -E 's/^( +run: \.\/Tools\/test-core\.sh)$/\1 || true/'
expect_refused "the gate step removed" test.yml sed -E '/run: zsh Tools\/release\/tests\/test-gate\.sh$/d'

echo "test-gate: nothing is drafted, built or published until lint, build and test pass on the pinned commit."
