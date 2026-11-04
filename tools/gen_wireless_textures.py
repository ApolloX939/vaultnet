"""VaultNet wireless relay textures. Usage: gen_wireless_textures.py <vaultnet_wireless dir> (needs Pillow)"""
import math, os, random, sys
from PIL import Image

mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)
random.seed(21)

def relay(accent, k):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            g = 0x4c + random.choice((-3, 0, 0, 3))
            c = (g, g, g + 8)
            if x in (0, 15) or y in (0, 15):
                c = (0x24, 0x26, 0x2e)
            elif x in (7, 8) or y in (7, 8):               # accent cross, like the cable lines
                c = tuple(int(a * k) for a in accent)
            im.putpixel((x, y), c + (255,))
    return im

random.seed(21)
relay((0x30, 0x38, 0x44), 1.0).save(f"{out}/vaultnet_wireless_relay.png")
FR = 8
strip = Image.new("RGBA", (16, 16 * FR))
for f in range(FR):
    random.seed(21)                                         # same metal in every frame
    k = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(2 * math.pi * f / FR))
    strip.paste(relay((0x40, 0xd8, 0xff), k), (0, 16 * f))
strip.save(f"{out}/vaultnet_wireless_relay_active.png")

# inventory icon: mast with a crossbar and ball on a base
icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
metal, dark, glow = (0x5a, 0x5f, 0x6b), (0x22, 0x24, 0x2b), (0x40, 0xd8, 0xff)
for x in range(3, 13):
    for y in range(10, 15):
        icon.putpixel((x, y), (dark if x in (3, 12) or y in (10, 14) else metal) + (255,))
for y in range(4, 10):
    for x in (7, 8):
        icon.putpixel((x, y), metal + (255,))
for x in range(4, 12):
    icon.putpixel((x, 6), metal + (255,))
for x in (7, 8):
    for y in (2, 3):
        icon.putpixel((x, y), glow + (255,))
for x in (4, 11):
    icon.putpixel((x, 5), glow + (255,))
icon.save(f"{out}/vaultnet_wireless_icon.png")
