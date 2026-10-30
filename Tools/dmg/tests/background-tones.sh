#!/bin/zsh
# The background's colours against the app icon they are derived from, so an
# icon recoloured in Resources/UnifiedDev.icon/icon.json cannot leave
# Tools/dmg/background.html painting the old violet.
#
#   zsh Tools/dmg/tests/background-tones.sh
#
# The derivation is the one the head of background.html states: hold the icon's
# OKLCH hue, take 0.45 of its chroma, and move only the lightness, by 1.72 for
# the top of the field, 1.62 for the bottom and 0.48 for the arrow, clipping
# each channel into sRGB. This asserts the rule reproduces the hexadecimals in
# the file rather than asserting the hexadecimals themselves, which is the only
# version of the check that catches a recoloured icon.
#
# It reads paint out of the places paint can live, the gradient in the style
# block and the paint attributes in the SVG, rather than searching the file for
# colour literals. A plain search passed a solid black rectangle laid over the
# whole window, because the three expected strings were still somewhere in the
# file, and failed on an id like url(#facade) that happens to spell six
# hexadecimal digits. Reading the attributes answers both.
#
# The field has to stay the light end of the family, which is a legibility
# requirement rather than a taste: Finder draws the two labels in the system
# label colour, no key in the .DS_Store can change it, and on a light mode Mac
# it is near black. So the contrast is asserted too. Without that the
# derivation degenerates quietly, because the lightness ratios are unbounded: a
# lighter icon drives both field tones to #FFFFFF and a black icon drives all
# three tones to #000000, which is a window whose labels and arrow have both
# disappeared.

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
    return '#%02X%02X%02X' % tuple(math.floor(v * 255 + 0.5) for v in rgb)


def luminance(colour):
    channels = [srgb_to_lin(int(colour[i:i + 2], 16) / 255) for i in (1, 3, 5)]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(one, other):
    a, b = luminance(one), luminance(other)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


# Finder's own label colour on a light mode Mac, measured off the mounted
# window. It is the thing the field has to be readable behind.
LABEL = '#07010C'
MINIMUM_CONTRAST = 4.5

icon = json.loads(open('Resources/UnifiedDev.icon/icon.json').read())
fill = icon.get('fill')
if not isinstance(fill, dict) or 'solid' not in fill:
    sys.exit('the icon fill is %r. This derivation reads a solid fill, and a '
             'gradient fill has more than one colour to derive from, so it '
             'needs a decision rather than a guess.' % (fill,))
solid = fill['solid']
if not isinstance(solid, str) or not solid.startswith('srgb:'):
    sys.exit('the icon fill is %r, which this derivation cannot read' % (solid,))
components = [float(v) for v in solid[len('srgb:'):].split(',')]
if len(components) < 3:
    sys.exit('the icon fill is %r, which is not three channels' % (solid,))

lightness, chroma, hue = to_oklch(components[:3])
top = to_hex(lightness * 1.72, chroma * 0.45, hue)
bottom = to_hex(lightness * 1.62, chroma * 0.45, hue)
arrow = to_hex(lightness * 0.48, chroma * 0.45, hue)
allowed = {top, bottom, arrow}

source = open('Tools/dmg/background.html').read()
source = re.sub(r'<!--.*?-->', '', source, flags=re.S)
source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)

failures = []

gradient = re.search(r'background:linear-gradient\(([^)]*)\)', source)
if not gradient:
    failures.append('the field is not a linear-gradient any more, so nothing '
                    'here knows which tone is the top one')
else:
    stops = [part.strip() for part in gradient.group(1).split(',')]
    if stops[:1] != ['180deg']:
        failures.append('the field runs %r rather than 180deg, so the light end '
                        'is no longer the one the labels sit on' % (stops[0],))
    painted_stops = [re.sub(r'\s.*$', '', stop).upper() for stop in stops[1:]]
    if painted_stops != [top, bottom]:
        failures.append('the field runs %s, and the derivation says %s to %s'
                        % (' to '.join(painted_stops) or 'nowhere', top, bottom))

PAINT_ATTRIBUTES = ('fill', 'stroke', 'stop-color', 'color', 'flood-color')
for attribute, value in re.findall(
        r'\b(%s)="([^"]*)"' % '|'.join(PAINT_ATTRIBUTES), source):
    if value == 'none' or value.upper() in allowed:
        continue
    failures.append('%s="%s" is painted and derives from nothing. Every colour '
                    'in the artwork comes from the icon, so a new one needs a '
                    'lightness ratio in the head comment and a line here.'
                    % (attribute, value))

if top == bottom:
    failures.append('both ends of the field came out %s, so the gradient is '
                    'flat. The lightness ratios have run past what sRGB holds '
                    'for this icon and the derivation needs rethinking rather '
                    'than reapplying.' % top)
for name, tone in (('the top of the field', top), ('the bottom of the field', bottom)):
    if contrast(tone, LABEL) < MINIMUM_CONTRAST:
        failures.append("%s is %s, which reads %.2f:1 against Finder's label "
                        'colour %s. Below %s:1 the two labels are unreadable, '
                        'which is the whole reason the field is the light end.'
                        % (name, tone, contrast(tone, LABEL), LABEL, MINIMUM_CONTRAST))
    if contrast(arrow, tone) < MINIMUM_CONTRAST:
        failures.append('the arrow %s reads %.2f:1 against %s (%s)'
                        % (arrow, contrast(arrow, tone), name, tone))

if failures:
    print('The background no longer follows the icon:', file=sys.stderr)
    for failure in failures:
        print('  %s' % failure, file=sys.stderr)
    sys.exit(1)

print('Background tone checks passed (field %s to %s, arrow %s, labels %.1f:1)'
      % (top, bottom, arrow, contrast(bottom, LABEL)))
PY
