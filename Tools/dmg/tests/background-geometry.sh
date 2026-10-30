#!/bin/zsh
# The arrow in Tools/dmg/background.html against the icon locations in
# Tools/dmg/settings.py, which are the two numbers the whole drawing hangs off
# and which live in a different file with nothing connecting them.
#
#   zsh Tools/dmg/tests/background-geometry.sh
#
# Move an icon in settings.py and the arrow keeps its coordinates, so it ends
# up pointing into a tile or out of the window, and the disk image still builds
# and still mounts. That is the drift this closes. It reads both files and
# recomputes the gap, so no render and no mount is needed.
#
# The two insets below are measurements rather than settings, taken the way the
# head of background.html prescribes: render the icon at 512 with NSWorkspace,
# which is the tile as Finder draws it, and take the bounding box of the alpha
# above 240. Our icon fills 50..461 of that render and the generic folder
# 21..490, divided by four for a 128pt tile and taken inclusive.

set -euo pipefail
cd "$(dirname "$0")/../../.."

python3 -I - <<'PY'
import re
import sys

APP_ARTWORK_RIGHT_INSET = 115.25
FOLDER_ARTWORK_LEFT_INSET = 5.25
APP_ARTWORK_TOP_INSET = 12.5
TILE_ORIGIN_Y = 126.7
TOLERANCE = 0.01

settings = open('Tools/dmg/settings.py').read()


def located(name):
    found = re.search(r"'%s':\s*\((-?[\d.]+),\s*(-?[\d.]+)\)" % re.escape(name), settings)
    if not found:
        sys.exit('settings.py no longer locates %s, so there is nothing to '
                 'measure the arrow against' % name)
    return float(found.group(1)), float(found.group(2))


def valued(name):
    found = re.search(r'^%s\s*=\s*([\d.]+)' % re.escape(name), settings, re.M)
    if not found:
        sys.exit('settings.py no longer sets %s' % name)
    return float(found.group(1))


icon_size = valued('icon_size')
app_x, app_y = located('UnifiedDev.app')
applications_x, applications_y = located('Applications')

source = open('Tools/dmg/background.html').read()
source = re.sub(r'<!--.*?-->', '', source, flags=re.S)

stroke = re.search(r'stroke-width="([\d.]+)"', source)
paths = re.findall(r'<path d="([^"]*)"', source)
if not stroke or len(paths) != 2:
    sys.exit('background.html no longer draws one stroke width and two paths, '
             'so this check cannot read the arrow')
overhang = float(stroke.group(1)) / 2


def points(definition):
    return [(float(x), float(y)) for x, y in
            re.findall(r'(-?[\d.]+)\s+(-?[\d.]+)', definition)]


shaft, chevron = points(paths[0]), points(paths[1])
if len(shaft) != 2 or len(chevron) != 3:
    sys.exit('the arrow is no longer a two point shaft and a three point '
             'chevron, so this check cannot read it')

(shaft_start_x, shaft_y), (shaft_end_x, shaft_end_y) = shaft
(back_top_x, back_top_y), (vertex_x, vertex_y), (back_bottom_x, back_bottom_y) = chevron

# The gap is what is left of the row once Finder has drawn both pieces of
# artwork, and the drawn arrow is the path plus the round cap and the round
# join, each of which reaches half a stroke width outside it.
gap_left = app_x - icon_size / 2 + APP_ARTWORK_RIGHT_INSET
gap_right = applications_x - icon_size / 2 + FOLDER_ARTWORK_LEFT_INSET
drawn_left = shaft_start_x - overhang
drawn_right = vertex_x + overhang
centre_line = TILE_ORIGIN_Y + (APP_ARTWORK_TOP_INSET + APP_ARTWORK_RIGHT_INSET) / 2

failures = []
if app_y != applications_y:
    failures.append('settings.py puts the two icons on different rows, y %s and '
                    '%s, so there is no shared centre line to draw on'
                    % (app_y, applications_y))
if drawn_left < gap_left:
    failures.append('the arrow starts at %.2f and the app icon reaches %.2f, so '
                    'it is drawn over the tile' % (drawn_left, gap_left))
if drawn_right > gap_right:
    failures.append('the arrow reaches %.2f and the folder starts at %.2f, so '
                    'it is drawn over the tile' % (drawn_right, gap_right))

clearances = (drawn_left - gap_left, gap_right - drawn_right)
if abs(clearances[0] - clearances[1]) > TOLERANCE:
    failures.append('the arrow clears the app icon by %.2f and the folder by '
                    '%.2f, so it is not centred in the gap the way the comment '
                    'claims' % clearances)

# The one the comment records two wrong answers for: a cap that stops short of
# the vertex leaves a pinhole against the upper arm, and one that runs past it
# swells behind the head.
if abs(shaft_end_x + overhang - vertex_x) > TOLERANCE:
    failures.append("the shaft's cap closes at %.2f and the chevron's vertex is "
                    'at %.2f. Short of it leaves a pinhole and past it swells '
                    'behind the head.' % (shaft_end_x + overhang, vertex_x))

if not shaft_y == shaft_end_y == vertex_y:
    failures.append('the shaft runs from y %s to %s and the vertex is at y %s, '
                    'so the arrow is not level' % (shaft_y, shaft_end_y, vertex_y))
if abs((back_top_y + back_bottom_y) / 2 - vertex_y) > TOLERANCE:
    failures.append('the chevron arms sit at y %s and %s, which is not '
                    'symmetric about the vertex at %s'
                    % (back_top_y, back_bottom_y, vertex_y))
if abs(back_top_x - back_bottom_x) > TOLERANCE:
    failures.append('the chevron arms end at x %s and %s, so the head is skewed'
                    % (back_top_x, back_bottom_x))
if abs(shaft_y - centre_line) > 0.1:
    failures.append('the arrow sits on y %s and the two tiles share y %.2f'
                    % (shaft_y, centre_line))

if failures:
    print('The arrow no longer agrees with the icon locations:', file=sys.stderr)
    for failure in failures:
        print('  %s' % failure, file=sys.stderr)
    sys.exit(1)

print('Background geometry checks passed (%.2fpt arrow centred in the %.2fpt '
      'gap, %.2fpt each side)'
      % (drawn_right - drawn_left, gap_right - gap_left, clearances[0]))
PY
