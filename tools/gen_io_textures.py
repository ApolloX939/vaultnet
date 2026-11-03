"""VaultNet IO textures. Usage: gen_io_textures.py <textures dir>  (needs Pillow)"""
import sys
from PIL import Image
out = sys.argv[1]

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
