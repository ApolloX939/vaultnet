import sys
from PIL import Image
out = sys.argv[1]
BASE = [(0x2e,0x31,0x38),(0x3a,0x3d,0x44),(0x45,0x49,0x52)]

def base_px(x, y):
    # dark brushed metal with a lighter rail along the edges
    c = BASE[1]
    if x in (0, 15): c = BASE[0]
    elif x in (1, 14): c = BASE[2]
    elif (x + y) % 5 == 0: c = BASE[2]
    return c

def on_cross(x, y):
    # the cable's centre lines (arms are 4px wide around the middle)
    return x in (7, 8) or y in (7, 8)

def tile(accent=None):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = accent if accent and on_cross(x, y) else base_px(x, y)
            im.putpixel((x, y), c + (255,))
    return im

def ring(x, y):
    # 0 = centre .. 7 = outermost, square rings around the tile centre
    return max(int(abs(x - 7.5)), int(abs(y - 7.5)))

PAUSE = 2          # dark frames between pulses
STEPS = 8          # ring 7 -> ring 0
FRAMES = STEPS + PAUSE

def animated(dim, bright, path):
    """Pulse starts at the node edges and contracts to the centre, then repeats."""
    strip = Image.new("RGBA", (16, 16 * FRAMES))
    for f in range(FRAMES):
        im = tile(dim)
        if f < STEPS:
            head = 7 - f
            for y in range(16):
                for x in range(16):
                    if not on_cross(x, y):
                        continue
                    r = ring(x, y)
                    if r == head:
                        im.putpixel((x, y), bright[0] + (255,))
                    elif r == head + 1:
                        im.putpixel((x, y), bright[1] + (255,))
                    elif r == head + 2:
                        im.putpixel((x, y), bright[2] + (255,))
        strip.paste(im, (0, 16 * f))
    strip.save(path)

tile().save(f"{out}/vaultnet_cables_cable.png")
tile((0x2f, 0xb0, 0x4a)).save(f"{out}/vaultnet_cables_toggle_on.png")
tile((0xb0, 0x30, 0x30)).save(f"{out}/vaultnet_cables_toggle_off.png")

animated((0x1d, 0x6f, 0x8f),
         [(0x7f,0xf0,0xff),(0x4a,0xd0,0xf0),(0x2a,0xa0,0xc8)],
         f"{out}/vaultnet_cables_cable_active.png")
animated((0x1f, 0x80, 0x38),
         [(0xa0,0xff,0xb0),(0x60,0xe0,0x78),(0x3a,0xb8,0x50)],
         f"{out}/vaultnet_cables_toggle_on_active.png")
