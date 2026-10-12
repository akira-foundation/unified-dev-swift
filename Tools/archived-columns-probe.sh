#!/bin/zsh
# Runs the archived selection column regression in this worktree's preview app,
# off screen, against a fixture it creates and removes again.
#
#   make preview && ./Tools/archived-columns-probe.sh
#
# A NavigationSplitView only says which of its columns are on screen once it has
# drawn in a real window, so this opens one with `open -g` and reads the split
# items behind it. A copy of the bundle is no use here: a bundle LaunchServices
# has not installed opens with no connection to the window server and draws
# nothing at all, which lsappinfo reports as !cgsConnection.
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

probe_root="$(mktemp -d "${TMPDIR:-/tmp}/unifieddev-archived-columns.XXXXXX")"

python3 - "$app_path" "$probe_root" <<'PY'
import json
import pathlib
import subprocess
import sys
import time

app, root = sys.argv[1:]
binary = pathlib.Path(app, 'Contents/MacOS/UnifiedDev')
if b'archived-columns' not in binary.read_bytes():
    raise SystemExit('The preview app predates this probe. Run make preview again.')
failed = []
for case, width, size in (('wide', '4000', '1600x900'), ('narrow', '600', '860x700')):
    report = pathlib.Path(root, f'{case}.json')
    subprocess.run(
        ['open', '-g', '-n', '-a', app,
         '--args', '--archived-columns-probe', str(report),
         '--window-available-width', width, '--window-size', size, '--window-hidden'],
        timeout=300, check=False,
    )
    for _ in range(300):
        if report.exists():
            break
        time.sleep(1)
    text = report.read_text() if report.exists() else ''
    print(f'== {case} (screen {width}pt, window {size})')
    print(text or 'the probe wrote no report')
    if not text or not json.loads(text).get('passed'):
        failed.append(case)
if failed:
    raise SystemExit(f'the archived columns probe failed in {", ".join(failed)}; evidence: {root}')
print(f'Probe evidence: {root}')
PY
