#!/bin/zsh
# The background's three tones against the app icon they are derived from, so an
# icon recoloured in Resources/UnifiedDev.icon/icon.json cannot leave
# Tools/dmg/background.html painting the old violet.
#
#   zsh Tools/dmg/tests/background-tones.sh
#
# The derivation is the one the head of background.html states: hold the icon's
# OKLCH hue, take 0.45 of its chroma, and move only the lightness, by 1.72 for
# the top of the field, 1.62 for the bottom and 0.48 for the arrow, clipping
# each result into sRGB. This asserts the rule reproduces the hexadecimals in
# the file rather than asserting the hexadecimals themselves, which is the only
# version of the check that catches a recoloured icon. The comments are cut out
# before the colours are read, because the head quotes the icon's own hexadecimal
# and that one is documentation rather than paint.

set -euo pipefail
cd "$(dirname "$0")/../../.."

python3 -I - <<'PY'
import json
import math
import re
import sys


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


M1 = [[0.4122214708, 0.5363325363, 0.0514459929],
      [0.2119034982, 0.6806995451, 0.1073969566],
      [0.0883024619, 0.2817188376, 0.6299787005]]
M2 = [[0.2104542553, 0.7936177850, -0.0040720468],
      [1.9779984951, -2.4285922050, 0.4505937099],
      [0.0259040371, 0.7827717662, -0.8086757660]]


def mul(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]


def inverse(m):
    (a, b, c), (d, e, f), (g, h, i) = m
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    return [[(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
            [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
            [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det]]


M1I, M2I = inverse(M1), inverse(M2)


def to_oklch(rgb):
    lms = mul(M1, [srgb_to_lin(v) for v in rgb])
    lms = [math.copysign(abs(v) ** (1 / 3), v) for v in lms]
    lightness, a, b = mul(M2, lms)
    return lightness, math.hypot(a, b), math.atan2(b, a)


def to_hex(lightness, chroma, hue):
    a, b = chroma * math.cos(hue), chroma * math.sin(hue)
    lms = [v ** 3 for v in mul(M2I, [lightness, a, b])]
    rgb = [lin_to_srgb(max(0.0, min(1.0, v))) for v in mul(M1I, lms)]
    return '#%02X%02X%02X' % tuple(round(v * 255) for v in rgb)


icon = json.loads(open('Resources/UnifiedDev.icon/icon.json').read())
solid = icon['fill']['solid']
if not solid.startswith('srgb:'):
    sys.exit('the icon fill is %r, which this derivation cannot read' % solid)
fill = [float(v) for v in solid[len('srgb:'):].split(',')[:3]]

lightness, chroma, hue = to_oklch(fill)
expected = {
    'the top of the field': to_hex(lightness * 1.72, chroma * 0.45, hue),
    'the bottom of the field': to_hex(lightness * 1.62, chroma * 0.45, hue),
    'the arrow': to_hex(lightness * 0.48, chroma * 0.45, hue),
}

source = open('Tools/dmg/background.html').read()
painted_source = re.sub(r'<!--.*?-->', '', source, flags=re.S)
painted = {m.group(0).upper() for m in re.finditer(r'#[0-9A-Fa-f]{6}\b', painted_source)}

failures = [
    '%s should be %s, and no such colour is painted' % (name, want)
    for name, want in expected.items() if want not in painted
]
unexpected = sorted(painted - set(expected.values()))
if unexpected:
    failures.append('these colours are painted and derive from nothing: %s'
                    % ', '.join(unexpected))

if failures:
    print('The background no longer follows the icon:', file=sys.stderr)
    for failure in failures:
        print('  %s' % failure, file=sys.stderr)
    sys.exit(1)

print('Background tone checks passed (%s)' % ', '.join(sorted(expected.values())))
PY
