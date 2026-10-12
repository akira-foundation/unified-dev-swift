#!/bin/zsh
# Measures every view that asks for its ideal height inside a container whose width is only
# bounded further up the tree, the construction that emptied the window in #241.
#
#   make preview && ./Tools/unbounded-height-probe.sh
#
# Two readings per subject, because neither alone decides. The height a subject asks for at the
# widths its host can offer says whether the request can escape at all; the energy the window
# server reports for the window it lives in says whether the window stopped drawing. A control
# pair reproduces the archive card before and after the #241 fix, so a sweep that cannot tell
# those two apart fails before anything below it is read.
#
# A copy of the bundle is no use here: a bundle LaunchServices has not installed opens with no
# connection to the window server and draws nothing at all, which lsappinfo reports as
# !cgsConnection.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .build/preview/identity.env ] || {
  echo "No preview app in this worktree. Run make preview first." >&2
  exit 1
}
app_path="$(sed -n 's/^app_path=//p' .build/preview/identity.env)"
[ -d "$app_path" ] || { echo "$app_path is missing. Run make preview again." >&2; exit 1; }
if [ -n "$(find Sources -type f -newer "$app_path/Contents/MacOS/UnifiedDev" -print -quit)" ]; then
  echo "The preview app is older than the sources. Run make preview again." >&2
  exit 1
fi

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/unifieddev-unbounded-height.XXXXXX")"

python3 - "$app_path" "$probe_root" "$PWD" <<'PY'
import json
import pathlib
import subprocess
import sys
import time

app, root, repo = sys.argv[1:]
binary = pathlib.Path(app, 'Contents/MacOS/UnifiedDev')
if b'unbounded-height' not in binary.read_bytes():
    raise SystemExit('The preview app predates this probe. Run make preview again.')
scenario = str(pathlib.Path(repo, 'Tools/scenarios/unbounded-height.json'))
failed = []
for case, appearance, size in (('light', 'light', '1600x900'), ('dark', 'dark', '980x720')):
    report = pathlib.Path(root, f'{case}.json')
    subprocess.run(
        ['open', '-g', '-n', '-a', app,
         '--stdout', f'{root}/{case}.out', '--stderr', f'{root}/{case}.log',
         '--args', '--unbounded-height-probe', str(report),
         '--scenario', scenario,
         '--appearance', appearance,
         '--window-size', size, '--window-hidden'],
        timeout=900, check=False,
    )
    for _ in range(240):
        if report.exists():
            break
        time.sleep(1)
    text = report.read_text() if report.exists() else ''
    print(f'== {case} ({appearance}, window {size})')
    print(text or 'the probe wrote no report')
    log = pathlib.Path(root, f'{case}.log')
    if not text and log.exists():
        print(log.read_text()[-4000:])
    if not text or not json.loads(text).get('passed'):
        failed.append(case)
if failed:
    raise SystemExit(f'the unbounded height probe failed in {", ".join(failed)}; evidence: {root}')
print(f'Probe evidence: {root}')
PY
