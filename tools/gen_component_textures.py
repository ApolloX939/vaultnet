"""VaultNet component icons. Usage: gen_component_textures.py <vaultnet_components dir> (needs Pillow)"""
import math, os, random, sys
from PIL import Image

mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)
random.seed(17)

STEEL, DARK, COPPER = (0x9a, 0xa0, 0xac), (0x22, 0x24, 0x2b), (0xd8, 0x80, 0x40)
GOLD, GREEN, CYAN, ORANGE = (0xe8, 0xc0, 0x40), (0x2a, 0x8a, 0x4a), (0x40, 0xd0, 0xff), (0xff, 0x90, 0x20)

def canvas(): return Image.new("RGBA", (16, 16), (0, 0, 0, 0))
def px(im, x, y, c):
    if 0 <= x < 16 and 0 <= y < 16: im.putpixel((x, y), tuple(c) + (255,))
def rect(im, x0, y0, x1, y1, c, edge=None):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            e = edge and (x in (x0, x1) or y in (y0, y1))
            px(im, x, y, edge if e else c)
def shade(c, k): return tuple(max(0, min(255, int(v * k))) for v in c)

icons = {}

im = canvas()                                            # wire: a loose coil
for i in range(24):
    a = i / 24 * 6.28 * 2.2
    r = 2 + i * 0.22
    px(im, int(8 + math.cos(a) * r), int(8 + math.sin(a) * r * 0.8), COPPER)
for i in range(3): px(im, 12 + i, 12 + i, (0x30, 0x30, 0x36))
icons["wire"] = im

im = canvas()                                            # coil: ring of windings
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 7.5)
        if 3.2 < d < 6.6:
            px(im, x, y, shade(COPPER, 1.0 if (x + y) % 3 else 0.7))
icons["coil"] = im

im = canvas(); rect(im, 2, 3, 13, 13, STEEL, DARK)      # casing
for (x, y) in ((3, 4), (12, 4), (3, 12), (12, 12)): px(im, x, y, DARK)
rect(im, 5, 6, 10, 10, shade(STEEL, 0.6), DARK)
icons["casing"] = im

im = canvas(); rect(im, 1, 2, 14, 13, GREEN, DARK)      # circuit board
for x in range(3, 13, 3): rect(im, x, 4, x, 11, shade(GREEN, 1.6))
rect(im, 5, 6, 8, 8, DARK); px(im, 11, 4, GOLD); px(im, 11, 11, GOLD)
icons["circuit"] = im

im = canvas(); rect(im, 4, 4, 11, 11, (0x18, 0x18, 0x1c), (0x08, 0x08, 0x0a))   # processor
for i in range(5, 11, 2):
    for (x, y) in ((i, 2), (i, 12)): rect(im, x, y, x, y + 1, GOLD)
    for (x, y) in ((2, i), (12, i)): rect(im, x, y, x + 1, y, GOLD)
px(im, 6, 6, (0x50, 0x50, 0x58))
icons["processor"] = im

im = canvas()                                            # actuator: gear + arm
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 7.5)
        a = math.atan2(y - 7.5, x - 7.5)
        tooth = 5.8 if int((a + 3.2) / 0.52) % 2 == 0 else 4.4
        if 2.0 < d < tooth: px(im, x, y, STEEL if d > 3.0 else shade(STEEL, 0.5))
rect(im, 7, 1, 8, 4, COPPER)
icons["actuator"] = im

for i, col in enumerate([(0x70, 0xa0, 0xd0), (0x50, 0xd0, 0x70), (0xd0, 0xb0, 0x40), (0xd0, 0x60, 0xf0)], 1):
    im = canvas()                                        # storage cell: platter stack + tier band
    for k in range(3):
        for x in range(3, 13):
            px(im, x, 4 + k * 3, STEEL); px(im, x, 5 + k * 3, shade(STEEL, 0.6))
    rect(im, 2, 3, 3, 13, shade(col, 0.8)); rect(im, 12, 3, 13, 13, shade(col, 0.8))
    for n in range(i): px(im, 5 + n * 2, 14, col)
    icons[f"cell_{i}"] = im

im = canvas()                                            # transceiver: mast and waves
rect(im, 7, 6, 8, 13, STEEL); rect(im, 5, 13, 10, 14, DARK)
px(im, 7, 4, CYAN); px(im, 8, 4, CYAN)
for r in (3, 5):
    for a in (-1.0, 1.0):
        px(im, int(7.5 + a * r), 4, shade(CYAN, 0.7)); px(im, int(7.5 + a * r), 3 if r == 3 else 2, shade(CYAN, 0.5))
icons["transceiver"] = im

im = canvas()                                            # resonator: faceted crystal
for y in range(16):
    for x in range(16):
        d = abs(x - 7.5) * 0.85 + abs(y - 7.5) * 0.6
        if d < 5.2:
            k = 1.25 - (x + y) / 30
            px(im, x, y, shade((0xb0, 0x70, 0xff) if (x + y) % 5 else CYAN, k))
icons["resonator"] = im

im = canvas(); rect(im, 5, 3, 10, 13, STEEL, DARK)       # capacitor: can with a band
rect(im, 5, 6, 10, 8, ORANGE); rect(im, 6, 1, 6, 2, COPPER); rect(im, 9, 1, 9, 2, COPPER)
icons["capacitor"] = im

im = canvas(); rect(im, 3, 6, 12, 13, shade(STEEL, 0.7), DARK)   # coupler: socket with prongs
for x in (5, 7, 9, 11): rect(im, x, 2, x, 6, COPPER)
rect(im, 5, 9, 10, 10, (0x10, 0x10, 0x14))
icons["coupler"] = im

for name, img in icons.items():
    img.save(f"{out}/vaultnet_components_{name}.png")
