#!/usr/bin/env python3
"""Generates the alternate app icons (1024×1024 PNG, opaque) straight into
the asset catalog. Pure Python — no Pillow, no ImageMagick — so it runs
anywhere, and every icon is reproducible from this file alone.

    python3 Tools/make-icons.py

Geometry, not fonts: the glyph is a mortarboard drawn from a diamond, a cap
body and a tassel, so no machine's font set changes the result.
"""
import json
import math
import os
import random
import struct
import zlib

SIZE = 1024
SUB = 4  # vertical supersampling per pixel row
ROOT = os.path.join(os.path.dirname(__file__), "..", "SchulportalMobile", "Assets.xcassets")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# --- shapes: each returns [(x0, x1)] float spans for a given (float) y ----

def polygon(points):
    """Convex polygon."""
    def spans(y):
        xs = []
        n = len(points)
        for i in range(n):
            (x0, y0), (x1, y1) = points[i], points[(i + 1) % n]
            if y0 == y1:
                continue
            if (y0 <= y < y1) or (y1 <= y < y0):
                xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        if len(xs) < 2:
            return []
        return [(min(xs), max(xs))]
    return spans


def ellipse(cx, cy, rx, ry):
    def spans(y):
        dy = (y - cy) / ry
        if abs(dy) >= 1:
            return []
        dx = rx * math.sqrt(1 - dy * dy)
        return [(cx - dx, cx + dx)]
    return spans


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def rect(x0, y0, x1, y1):
    return polygon([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def union(*shapes):
    def spans(y):
        out = []
        for s in shapes:
            out.extend(s(y))
        out.sort()
        merged = []
        for a, b in out:
            if merged and a <= merged[-1][1]:
                merged[-1] = (merged[-1][0], max(merged[-1][1], b))
            else:
                merged.append((a, b))
        return merged
    return spans


def thick_line(x0, y0, x1, y1, w):
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1
    nx, ny = -dy / length * w / 2, dx / length * w / 2
    return polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])


def mortarboard(cx=512, cy=470, scale=1.0):
    s = scale
    diamond = polygon([(cx, cy - 175 * s), (cx + 350 * s, cy), (cx, cy + 175 * s), (cx - 350 * s, cy)])
    body = union(rect(cx - 185 * s, cy + 60 * s, cx + 185 * s, cy + 200 * s),
                 ellipse(cx, cy + 200 * s, 185 * s, 42 * s))
    tassel = union(thick_line(cx + 350 * s, cy, cx + 350 * s, cy + 150 * s, 14 * s),
                   circle(cx + 350 * s, cy + 165 * s, 24 * s))
    return union(diamond, body, tassel)


def heart(cx=512, cy=470):
    return union(circle(cx - 112, cy - 60, 160), circle(cx + 112, cy - 60, 160),
                 polygon([(cx - 268, cy - 10), (cx + 268, cy - 10), (cx, cy + 300)]))


# --- rasteriser ------------------------------------------------------------

class Canvas:
    def __init__(self, top, bottom, angle=True):
        self.rows = []
        t, b = hex_rgb(top), hex_rgb(bottom)
        # Diagonal gradient: colour depends on x + y only, so a row is one
        # slice of a precomputed strip.
        strip = bytearray()
        for s in range(2 * SIZE - 1):
            f = s / (2 * SIZE - 2) if angle else s / (2 * SIZE - 2)
            strip += bytes(int(round(t[i] + (b[i] - t[i]) * f)) for i in range(3))
        for y in range(SIZE):
            self.rows.append(bytearray(strip[3 * y:3 * (y + SIZE)]))

    def fill(self, shape, color, alpha=1.0):
        c = hex_rgb(color)
        for y in range(SIZE):
            cov = {}
            for k in range(SUB):
                yy = y + (k + 0.5) / SUB
                for a, b in shape(yy):
                    a = max(a, 0.0)
                    b = min(b, float(SIZE))
                    if b <= a:
                        continue
                    xa, xb = int(a), int(math.ceil(b))
                    for x in range(xa, min(xb, SIZE)):
                        lo, hi = max(a, x), min(b, x + 1)
                        if hi > lo:
                            cov[x] = cov.get(x, 0.0) + (hi - lo) / SUB
            if not cov:
                continue
            row = self.rows[y]
            for x, v in cov.items():
                v = min(v, 1.0) * alpha
                if v <= 0:
                    continue
                i = 3 * x
                for ch in range(3):
                    row[i + ch] = int(round(row[i + ch] * (1 - v) + c[ch] * v))

    def png(self):
        raw = b"".join(b"\x00" + bytes(r) for r in self.rows)

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

        return (b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9))
                + chunk(b"IEND", b""))


# --- the icons -------------------------------------------------------------

def notebook_lines(canvas):
    for y in range(196, SIZE, 92):
        canvas.fill(rect(0, y, SIZE, y + 4), "#9ec5e8", 0.9)
    canvas.fill(rect(168, 0, 174, SIZE), "#e0656b", 0.9)


def snow(canvas):
    rng = random.Random(5102)
    for _ in range(70):
        x, y, r = rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(5, 16)
        canvas.fill(circle(x, y, r), "#ffffff", rng.uniform(0.35, 0.8))


def sun(canvas):
    for i in range(16):
        a = i * math.pi / 8
        x1, y1 = 512 + 560 * math.cos(a), 470 + 560 * math.sin(a)
        canvas.fill(thick_line(512, 470, x1, y1, 34), "#ffffff", 0.16)
    canvas.fill(circle(512, 470, 380), "#ffffff", 0.22)


ICONS = [
    # name,               top,       bottom,    glyph,   glyph colour, decoration
    ("AppIconMitternacht", "#2a2a5e", "#0b0b1e", "cap", "#ffffff", None),
    ("AppIconMinze",       "#34d3bd", "#0d6e66", "cap", "#ffffff", None),
    ("AppIconLila",        "#b06cf7", "#5b21b6", "cap", "#ffffff", None),
    ("AppIconAbendrot",    "#fb923c", "#be185d", "cap", "#ffffff", None),
    ("AppIconMono",        "#fafafa", "#e5e5ea", "cap", "#1c1c1e", None),
    ("AppIconNotizbuch",   "#fdf6e3", "#f3e9c9", "cap", "#1f3a6e", notebook_lines),
    ("AppIconWeihnachten", "#1f7a3e", "#052e16", "cap", "#ffffff", snow),
    ("AppIconSommer",      "#fde047", "#f59e0b", "cap", "#ffffff", sun),
    ("AppIconUnterstuetzer", "#f43f5e", "#9f1239", "heart", "#ffffff", None),
]


def write(name, canvas):
    folder = os.path.join(ROOT, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f"{name}.png"), "wb") as f:
        f.write(canvas.png())
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for name, top, bottom, glyph, colour, deco in ICONS:
        canvas = Canvas(top, bottom)
        if deco:
            deco(canvas)
        canvas.fill(mortarboard() if glyph == "cap" else heart(), colour)
        write(name, canvas)
        print("written", name)
