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

def tile(accent=None, row_glow=None):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = base_px(x, y)
            if accent and x in (7, 8):
                c = accent
            im.putpixel((x, y), c + (255,))
    return im

# plain cable
tile().save(f"{out}/vaultnet_cables_cable.png")

# animated active cable: 8 frames, a bright pulse travels down the core line
frames = 8
strip = Image.new("RGBA", (16, 16 * frames))
for f in range(frames):
    im = tile((0x1d, 0x6f, 0x8f))
    for y in range(16):
        d = min((y - f * 2) % 16, (f * 2 - y) % 16)
        if d <= 2:
            k = [(0x7f,0xf0,0xff),(0x4a,0xd0,0xf0),(0x2a,0xa0,0xc8)][d]
            for x in (7, 8):
                im.putpixel((x, y), k + (255,))
    strip.paste(im, (0, 16 * f))
strip.save(f"{out}/vaultnet_cables_cable_active.png")

# toggle cable: on (green core) / off (red core)
tile((0x2f, 0xb0, 0x4a)).save(f"{out}/vaultnet_cables_toggle_on.png")
tile((0xb0, 0x30, 0x30)).save(f"{out}/vaultnet_cables_toggle_off.png")

# toggle on, active: green core with traveling light
strip = Image.new("RGBA", (16, 16 * frames))
for f in range(frames):
    im = tile((0x1f, 0x80, 0x38))
    for y in range(16):
        d = min((y - f * 2) % 16, (f * 2 - y) % 16)
        if d <= 2:
            k = [(0xa0,0xff,0xb0),(0x60,0xe0,0x78),(0x3a,0xb8,0x50)][d]
            for x in (7, 8):
                im.putpixel((x, y), k + (255,))
    strip.paste(im, (0, 16 * f))
strip.save(f"{out}/vaultnet_cables_toggle_on_active.png")
