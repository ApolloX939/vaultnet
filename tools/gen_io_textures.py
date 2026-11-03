"""VaultNet IO assets. Usage: gen_io_textures.py <vaultnet_io dir>  (needs Pillow)
Writes the terminal textures and the inserter/exporter inventory icons."""
import os, sys
from PIL import Image
mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)

METAL, EDGE, RAIL = (0x4a, 0x4e, 0x58), (0x20, 0x22, 0x28), (0x5a, 0x5f, 0x6b)

def base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else RAIL if x in (1, 14) or y in (1, 14) else METAL
            im.putpixel((x, y), c + (255,))
    return im

base().save(f"{out}/vaultnet_io_terminal_side.png")

def front(lines, fg, bg=(0x08, 0x0c, 0x12)):
    """Screen with text-like lines; `lines` = list of (row, length)."""
    im = base()
    for y in range(3, 13):
        for x in range(3, 13):
            im.putpixel((x, y), bg + (255,))
    for row, length in lines:
        for x in range(4, 4 + length):
            im.putpixel((x, 4 + row), fg + (255,))
    for x in (11, 12):                         # power LED
        im.putpixel((x, 14), fg + (255,))
    return im

DIM = (0x30, 0x38, 0x44)
front([(0, 5), (2, 3), (4, 6)], DIM).save(f"{out}/vaultnet_io_terminal_front.png")

# active: text lines scroll upward, blue
BLUE = (0x30, 0xb0, 0xff)
PATTERN = [6, 3, 5, 0, 4, 6, 2, 0, 5, 4, 0, 6]    # line lengths (0 = blank row)
FRAMES = len(PATTERN)
strip = Image.new("RGBA", (16, 16 * FRAMES))
for f in range(FRAMES):
    lines = [(r, PATTERN[(f + r) % FRAMES]) for r in range(8)]
    strip.paste(front([l for l in lines if l[1] > 0], BLUE), (0, 16 * f))
strip.save(f"{out}/vaultnet_io_terminal_front_active.png")


# ---- inserter / exporter inventory icons --------------------------------
# Side view of the stepped plates (target at the bottom), as in Refined Storage's
# Importer/Exporter: the Exporter narrows towards the target, the Inserter widens.
def icon(halves, accent):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    plate, dark = (0x4a, 0x4e, 0x58), (0x22, 0x24, 0x2b)
    # core + cable stub up the middle
    for y in range(1, 9):
        for x in (6, 7, 8, 9):
            im.putpixel((x, y), (0x3a, 0x3d, 0x44, 255))
    y = 14
    for half in halves:                       # bottom (target side) upwards
        for yy in (y, y - 1):
            for x in range(8 - half, 8 + half):
                edge = x in (8 - half, 7 + half)
                im.putpixel((x, yy), (dark if edge else plate) + (255,))
        y -= 2
    for x in range(5, 11):                    # accent LED strip on the flow side
        im.putpixel((x, 15), accent + (255,))
    return im

icon([5, 3, 2], (0x30, 0xe0, 0x70)).save(f"{out}/vaultnet_io_inserter.png")   # wide at the target
icon([2, 3, 5], (0xff, 0x90, 0x20)).save(f"{out}/vaultnet_io_exporter.png")   # narrow at the target
