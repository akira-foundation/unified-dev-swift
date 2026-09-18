#!/usr/bin/env python3
"""Recolours a copy of the layered icon document so the dev build is unmistakable.

    python3 Tools/icon/dev-tint.py <path to a copy of UnifiedDev.icon>/icon.json [turn]

`turn` is the fraction of the colour wheel to rotate by. The default carries the
violet ground to orange; another identity passes its own, far enough from both.

Rewrites that file in place. It is only ever pointed at the detached worktree
Tools/dev-build.sh builds from, never at Resources/UnifiedDev.icon in the tree.

Every colour in the icon is an "srgb:r,g,b,a" string in icon.json, written by
Tools/icon/layers.py. The white layers have no saturation to rotate and stay
white, so the dev icon is the same mark on a different ground.
"""

import colorsys
import json
import sys

HUE_TURN = float(sys.argv[2]) if len(sys.argv) > 2 else 0.34

SATURATION_GAIN = 1.35


def tint(value: str) -> str:
    """One "srgb:r,g,b,a" string, rotated. Anything else is returned untouched."""
    if not value.startswith("srgb:"):
        return value

    parts = [float(component) for component in value[len("srgb:"):].split(",")]
    red, green, blue, alpha = parts

    hue, saturation, brightness = colorsys.rgb_to_hsv(red, green, blue)
    hue = (hue + HUE_TURN) % 1.0
    saturation = min(1.0, saturation * SATURATION_GAIN)
    red, green, blue = colorsys.hsv_to_rgb(hue, saturation, brightness)

    return "srgb:%.4f,%.4f,%.4f,%.4f" % (red, green, blue, alpha)


def walk(node):
    if isinstance(node, dict):
        return {key: walk(value) for key, value in node.items()}
    if isinstance(node, list):
        return [walk(item) for item in node]
    if isinstance(node, str):
        return tint(node)
    return node


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path) as handle:
        document = json.load(handle)

    tinted = walk(document)

    if tinted == document:
        print("dev-tint: no srgb: fills in %s, so nothing was recoloured" % path, file=sys.stderr)
        return 1

    with open(path, "w") as handle:
        json.dump(tinted, handle, indent=1)
        handle.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
