"""VaultNet autocrafter textures. Usage: gen_autocrafter_textures.py <vaultnet_autocrafter dir> (needs Pillow)"""
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

base().save(f"{out}/vaultnet_autocrafter_side.png")

# top: a lighter plate with a 3x3 hint
top = base()
for gx in range(3):
    for gy in range(3):
        for x in range(4 + gx * 3, 6 + gx * 3):
            for y in range(4 + gy * 3, 6 + gy * 3):
                top.putpixel((x, y), (0x3a, 0x3d, 0x44, 255))
top.save(f"{out}/vaultnet_autocrafter_top.png")

SLOT = (0x12, 0x14, 0x18)

def front(lit=None, accent=(0x30, 0xb0, 0xff), dim=(0x2a, 0x2e, 0x36)):
    """3x3 grid of slots (3x3 px each, 1 px apart); `lit` = slot index 0..8 to highlight."""
    im = base()
    for gy in range(3):
        for gx in range(3):
            i = gy * 3 + gx
            x0, y0 = 2 + gx * 4, 2 + gy * 4
            color = accent if lit == i else SLOT
            for x in range(x0, x0 + 3):
                for y in range(y0, y0 + 3):
                    im.putpixel((x, y), color + (255,))
    for x in (13, 14):                                  # LED bottom right
        im.putpixel((x, 14), (accent if lit is not None else dim) + (255,))
    return im

front().save(f"{out}/vaultnet_autocrafter_front.png")
strip = Image.new("RGBA", (16, 16 * 9))
for f in range(9):                                      # a highlight walks over the grid
    strip.paste(front(lit=f), (0, 16 * f))
strip.save(f"{out}/vaultnet_autocrafter_front_active.png")
