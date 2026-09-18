#!/usr/bin/env python3
"""Writes Unified Dev's layers mark: the layered app icon and the menu bar template.

    python3 Tools/icon/layers.py            rewrite Resources/UnifiedDev.icon and Resources/AppMenuBar.pdf
    python3 Tools/icon/layers.py --check    fail when Resources differs from what this writes

The mark is Lucide "Layers" (ISC, see LICENSE-THIRD-PARTY.md) in white on the
violet #7c3aed of the first Unified Dev.
"""

import argparse
import filecmp
import json
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

VIOLET = (0x7C / 255, 0x3A / 255, 0xED / 255)

LAYERS = [
    [(12, 2), (2, 7), (12, 12), (22, 7), (12, 2)],
    [(2, 12), (12, 17), (22, 12)],
    [(2, 17), (12, 22), (22, 17)],
]

CANVAS = 1024
MARK_SPAN = CANVAS * 260 / 512

MENU_HEIGHT = 18.0
MENU_ART = 16.0


def srgb(colour, alpha=1.0):
    return "srgb:%.4f,%.4f,%.4f,%.4f" % (colour[0], colour[1], colour[2], alpha)


def points(line):
    return " ".join("%g,%g" % point for point in line)


def mark_svg(stroke):
    scale = MARK_SPAN / 24
    offset = (CANVAS - MARK_SPAN) / 2
    shapes = "\n".join(
        '    <%s points="%s"/>' % ("polygon" if line[0] == line[-1] else "polyline", points(line[:-1] if line[0] == line[-1] else line))
        for line in LAYERS
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
        '  <g transform="translate(%g %g) scale(%.4f)" fill="none" stroke="#000" stroke-width="%g" '
        'stroke-linecap="round" stroke-linejoin="round">\n%s\n  </g>\n</svg>\n'
        % (CANVAS, CANVAS, CANVAS, CANVAS, offset, offset, scale, stroke, shapes)
    )


def layer(image, name, colour):
    return {
        "image-name": image,
        "name": name,
        "fill": {"solid": srgb(colour)},
    }


def group(content, translucency):
    return {
        "layers": [content],
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "specular": True,
        "translucency": {"enabled": translucency > 0, "value": translucency},
    }


def icon_json(mark_translucency):
    return {
        "fill": {"solid": srgb(VIOLET)},
        "groups": [
            group(layer("mark.svg", "Layers", (1.0, 1.0, 1.0)), mark_translucency),
        ],
        "supported-platforms": {"squares": ["macOS"]},
    }


def write_icon(directory, stroke, mark_translucency):
    assets = os.path.join(directory, "Assets")
    os.makedirs(assets, exist_ok=True)
    for stale in os.listdir(assets):
        os.remove(os.path.join(assets, stale))
    with open(os.path.join(assets, "mark.svg"), "w") as handle:
        handle.write(mark_svg(stroke))
    with open(os.path.join(directory, "icon.json"), "w") as handle:
        json.dump(icon_json(mark_translucency), handle, indent=1)
        handle.write("\n")


def menu_pdf(stroke):
    scale = MENU_ART / (20 + stroke)
    width = MENU_ART
    inset = (MENU_HEIGHT - MENU_ART) / 2
    origin = 2 - stroke / 2
    ops = [
        "0 G",
        "%.4f w" % (stroke * scale),
        "1 J",
        "1 j",
        "1 0 0 -1 0 %.4f cm" % MENU_HEIGHT,
    ]
    for line in LAYERS:
        mapped = [((x - origin) * scale, (y - origin) * scale + inset) for x, y in line]
        ops.append("%.4f %.4f m" % mapped[0])
        closed = line[0] == line[-1]
        ops += ["%.4f %.4f l" % point for point in (mapped[1:-1] if closed else mapped[1:])]
        ops.append("s" if closed else "S")
    return pdf_document(("\n".join(ops) + "\n").encode("ascii"), width, MENU_HEIGHT)


def pdf_document(stream, width, height):
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        (
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.4f %.4f] /Contents 4 0 R /Resources << >> >>"
            % (width, height)
        ).encode("ascii"),
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
    ]
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    start = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets:
        out += b"%010d 00000 n \n" % offset
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, start)
    return bytes(out)


OUTPUTS = ["UnifiedDev.icon/icon.json", "UnifiedDev.icon/Assets/mark.svg", "AppMenuBar.pdf"]


def write(resources, icon_stroke, menu_stroke, mark_translucency):
    write_icon(os.path.join(resources, "UnifiedDev.icon"), icon_stroke, mark_translucency)
    with open(os.path.join(resources, "AppMenuBar.pdf"), "wb") as handle:
        handle.write(menu_pdf(menu_stroke))


def differences(expected, actual):
    found = []
    for name in OUTPUTS:
        path = os.path.join(actual, name)
        if not os.path.isfile(path) or not filecmp.cmp(os.path.join(expected, name), path, shallow=False):
            found.append(name)
    assets = os.path.join(actual, "UnifiedDev.icon", "Assets")
    if os.path.isdir(assets):
        found += ["UnifiedDev.icon/Assets/" + name for name in sorted(os.listdir(assets)) if name != "mark.svg"]
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--resources", default=os.path.join(ROOT, "Resources"))
    parser.add_argument("--icon-stroke", type=float, default=1.8)
    parser.add_argument("--menu-stroke", type=float, default=2.0)
    parser.add_argument("--mark-translucency", type=float, default=0.0)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    strokes = (arguments.icon_stroke, arguments.menu_stroke, arguments.mark_translucency)

    if not arguments.check:
        write(arguments.resources, *strokes)
        return 0

    with tempfile.TemporaryDirectory() as expected:
        write(expected, *strokes)
        found = differences(expected, arguments.resources)
    for name in found:
        print("layers: %s is not what Tools/icon/layers.py writes" % name, file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
