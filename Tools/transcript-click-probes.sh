#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

bin_dir="$(swift build --show-bin-path)"
probe_root="$(mktemp -d "${TMPDIR:-/tmp}/unifieddev-click-probes.XXXXXX")"
probe_app="$probe_root/Unified Dev Click Probes.app"
mkdir -p "$probe_app/Contents/MacOS"
cp "$bin_dir/UnifiedDev" "$probe_app/Contents/MacOS/UnifiedDev"
cp Resources/Info.plist "$probe_app/Contents/Info.plist"
ditto Resources "$probe_app/Contents/Resources"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.akira.unifieddev.click-probes' "$probe_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Unified Dev Click Probes' "$probe_app/Contents/Info.plist"
codesign --force --deep --sign - "$probe_app" >/dev/null 2>&1

python3 - "$probe_app" "$probe_root" <<'PY'
import json
import os
import pathlib
import shutil
import subprocess
import sys

app, root = sys.argv[1:]
if b'--markdown-selection-probe' not in pathlib.Path(app, 'Contents/MacOS/UnifiedDev').read_bytes():
    raise SystemExit('Build the debug app with swift build before running these probes.')
probes = {
    'markdown-selection': ['--markdown-selection-probe', '--markdown-selection-probe-out', root],
    'selection-reply': ['--selection-reply-probe', f'{root}/selection-reply.json', '-preview.holdsSeededQuotas', 'YES'],
}
copies = ['--env', 'UD_PROBE_COPIES=1'] if os.environ.get('CI') else []
for name, arguments in probes.items():
    stdout = f'{root}/{name}.stdout'
    log = pathlib.Path(root, f'{name}.log')
    try:
        subprocess.run(
            ['open', '-g', '-n', '-W', '-a', app, '--env', f'UD_DB_PATH={root}/{name}.sqlite', *copies,
             '--stdout', stdout, '--stderr', str(log), '--args', *arguments],
            timeout=150, check=True,
        )
    except subprocess.TimeoutExpired:
        subprocess.run(['pkill', '-f', f'{app}/Contents/MacOS/UnifiedDev'])
        print(log.read_text(), file=sys.stderr)
        raise
    written = pathlib.Path(root, f'{name}.json')
    report = (written if written.exists() else pathlib.Path(stdout)).read_text()
    print(f'{name}: {report}')
    if not json.loads(report).get('passed'):
        print(log.read_text(), file=sys.stderr)
        raise SystemExit(f'{name} failed; evidence: {root}')
shutil.rmtree(root)
PY
