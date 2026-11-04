"""VaultNet machine textures. Usage: gen_machine_textures.py <vaultnet_machines dir> (needs Pillow)"""
import math, os, random, sys
from PIL import Image

mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)
random.seed(13)

METAL, EDGE, RAIL = (0x4a, 0x4e, 0x58), (0x20, 0x22, 0x28), (0x5a, 0x5f, 0x6b)
MACHINES = {
    "smelter": (0xff, 0x80, 0x20),
    "grinder": (0xc0, 0xc0, 0xd0),
    "compressor": (0x40, 0xb0, 0xff),
    "alloy": (0xe0, 0xb0, 0x30),
}

def base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else RAIL if x in (1, 14) or y in (1, 14) else METAL
            im.putpixel((x, y), c + (255,))
    return im

base().save(f"{out}/vaultnet_machines_side.png")

def window(im, color=(0x0c, 0x0e, 0x12)):
    for y in range(3, 12):
        for x in range(3, 13):
            im.putpixel((x, y), color + (255,))

def front(kind, accent, f=None):
    """f = animation phase 0..1, or None when idle."""
    im = base()
    window(im)
    dim = tuple(int(c * 0.35) for c in accent)
    lit = f is not None
    col = accent if lit else dim
    if kind == "smelter":                      # flame
        for x in range(5, 11):
            h = 3 + (int(2.5 + 2.5 * math.sin(x * 1.3 + (f or 0) * 6.28)) if lit else 0)
            for y in range(11 - h, 11):
                im.putpixel((x, y), col + (255,))
    elif kind == "grinder":                    # two toothed rollers
        shift = int((f or 0) * 4) if lit else 0
        for x in range(4, 12):
            on = ((x + shift) // 2) % 2 == 0
            for y in (6, 7) if on else (7, 8):
                im.putpixel((x, y), col + (255,))
    elif kind == "compressor":                 # plates closing in
        gap = 2 + (int(abs(math.sin((f or 0) * 3.14)) * 3) if lit else 3)
        for x in range(4, 12):
            for y in range(4, 4 + gap):
                im.putpixel((x, y), col + (255,))
                im.putpixel((x, 14 - y), col + (255,))
    else:                                      # alloy: two streams joining
        t = int((f or 0) * 5) if lit else 0
        for i in range(5):
            y = 4 + i
            im.putpixel((4 + (i + t) % 5, y), col + (255,))
            im.putpixel((11 - (i + t) % 5, y), col + (255,))
        for y in range(9, 11):
            for x in range(7, 9):
                im.putpixel((x, y), col + (255,))
    for x in (13, 14):                         # LED
        im.putpixel((x, 13), col + (255,))
    return im

def top(accent):
    im = base()
    for x in range(5, 11):
        for y in range(5, 11):
            im.putpixel((x, y), (0x34, 0x37, 0x3e, 255))
    for x in range(5, 11):
        im.putpixel((x, 5), accent + (255,))
    return im

for kind, accent in MACHINES.items():
    front(kind, accent).save(f"{out}/vaultnet_machines_{kind}_front.png")
    FR = 8
    strip = Image.new("RGBA", (16, 16 * FR))
    for i in range(FR):
        strip.paste(front(kind, accent, i / FR), (0, 16 * i))
    strip.save(f"{out}/vaultnet_machines_{kind}_front_active.png")
    top(accent).save(f"{out}/vaultnet_machines_{kind}_top.png")
