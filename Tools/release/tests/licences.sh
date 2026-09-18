#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/../../.."
fixture="$(mktemp -d "${TMPDIR:-/tmp}/unifieddev-licence-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/checkouts/SwiftTerm" "$fixture/checkouts/swift-argument-parser"
mkdir -p "$fixture/checkouts/swift-markdown-engine"
cp LICENSE "$fixture/checkouts/swift-markdown-engine/LICENSE"
cp LICENSE "$fixture/checkouts/SwiftTerm/LICENSE"
cp LICENSE "$fixture/checkouts/swift-argument-parser/LICENSE.txt"
zsh Tools/package-licences.sh "$fixture/UnifiedDev.app" "$fixture/checkouts"
notices="$fixture/UnifiedDev.app/Contents/Resources/Licences"
cmp LICENSE-THIRD-PARTY.md "$notices/ThirdParty.txt"
cmp Resources/Licences/Lucide.txt "$notices/Lucide.txt"
grep -q "^ISC License" "$notices/Lucide.txt"
grep -q "^## Lucide" "$notices/ThirdParty.txt"
for notice in UnifiedDev SwiftTerm SwiftArgumentParser MarkdownEngine; do
  cmp LICENSE "$notices/$notice.txt"
done
if zsh Tools/package-licences.sh "$fixture/Incomplete.app" "$fixture/missing" >/dev/null 2>&1; then
  echo "Packaging accepted missing dependency notices" >&2
  exit 1
fi
echo "Licence packaging checks passed"
