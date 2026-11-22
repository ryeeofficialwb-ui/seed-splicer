"""Seed Splicer's pixel font: Pixelify Sans with new, clearly different digits 0-9.

Pixelify's own digits are drawn off-grid (strokes ~100 units, 10-unit notches), so at the game's
26 px their details fall between pixels and 3 / 5 / 6 / 8 smear together. These digits are drawn
on an exact grid instead: one cell = 1000/13 units = exactly 1 screen pixel at 13 px and 2 at 26 px,
5 cells wide and 8 tall (the letters' cap height), merged into one outline per shape so the black
text stroke traces the digit, not every cell.

    python art/make_digits.py        (needs fonttools: pip install fonttools)

Reads assets/fonts/PixelifySans.ttf, writes assets/fonts/SeedSplicerPixel.ttf (the font the game
uses, see scripts/ui_kit.gd). SIL Open Font License 1.1: a modified version, so it has its own name.
"""
import os
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "fonts", "PixelifySans.ttf")
DST = os.path.join(ROOT, "assets", "fonts", "SeedSplicerPixel.ttf")
FAMILY = "Seed Splicer Pixel"

CELL = 1000.0 / 13.0  # one font pixel
ADVANCE_CELLS = 7     # 5 for the digit + 1 on each side (all digits the same width)

DIGITS = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#", ".###."],
    "1": ["..#..", ".##..", "#.#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#.", "...#."],
    "5": ["#####", "#....", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "...#.", "..#..", "..#..", "..#..", "..#.."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
}
NAMES = {"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
         "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine"}


def outline(rows):
    """The cells' boundary as closed loops of grid points (clockwise, y up), one per shape."""
    h = len(rows)
    filled = {(x, h - 1 - y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "#"}
    edges = set()
    for (x, y) in filled:  # each cell's edges, clockwise with y pointing up
        for e in [((x, y + 1), (x + 1, y + 1)), ((x + 1, y + 1), (x + 1, y)), ((x + 1, y), (x, y)), ((x, y), (x, y + 1))]:
            if (e[1], e[0]) in edges:
                edges.discard((e[1], e[0]))  # shared with a neighbour: inside the shape
            else:
                edges.add(e)
    out_from = {}
    for a, b in edges:
        out_from.setdefault(a, []).append(b)
    loops = []
    while out_from:
        start = next(iter(out_from))
        loop = [start]
        prev, cur = None, start
        while True:
            options = out_from[cur]
            if len(options) > 1 and prev is not None:  # a corner where two shapes touch: turn right
                dx, dy = cur[0] - prev[0], cur[1] - prev[1]
                right = (cur[0] + dy, cur[1] - dx)
                nxt = right if right in options else options[0]
            else:
                nxt = options[0]
            options.remove(nxt)
            if not options:
                del out_from[cur]
            prev, cur = cur, nxt
            if cur == start:
                break
            loop.append(cur)
        # drop points in the middle of straight runs
        simple = []
        n = len(loop)
        for i in range(n):
            a, b, c = loop[i - 1], loop[i], loop[(i + 1) % n]
            if (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) != 0:
                simple.append(b)
        loops.append(simple)
    return loops


def main():
    f = TTFont(SRC)
    cmap = f.getBestCmap()
    glyf = f["glyf"]
    for ch, rows in DIGITS.items():
        name = cmap[ord(ch)]
        pen = TTGlyphPen(None)
        for loop in outline(rows):
            pts = [(round((x + 1) * CELL), round(y * CELL)) for x, y in loop]  # 1 cell of left side bearing
            pen.moveTo(pts[0])
            for p in pts[1:]:
                pen.lineTo(p)
            pen.closePath()
        g = pen.glyph()
        glyf[name] = g
        g.recalcBounds(glyf)
        f["hmtx"][name] = (round(ADVANCE_CELLS * CELL), g.xMin)
        if "gvar" in f and name in f["gvar"].variations:
            del f["gvar"].variations[name]  # the bold axis would move points that no longer exist
    # a modified OFL font gets its own name
    for rec in f["name"].names:
        if rec.nameID in (1, 16):
            rec.string = FAMILY
        elif rec.nameID == 4:
            rec.string = FAMILY + " Regular"
        elif rec.nameID == 6:
            rec.string = FAMILY.replace(" ", "") + "-Regular"
        elif rec.nameID == 3:
            rec.string = FAMILY + " (Pixelify Sans with pixel-grid digits)"
    f.save(DST)
    print("wrote", DST)


if __name__ == "__main__":
    main()
