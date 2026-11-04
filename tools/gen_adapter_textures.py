"""VaultNet power adapter textures. Usage: gen_adapter_textures.py <modpack root> (needs Pillow)
Writes into vaultnet_power_technic/textures (lv, mv, hv) and vaultnet_power_techage/textures."""
import math, os, random, sys
from PIL import Image

root = sys.argv[1]
random.seed(9)
METAL, EDGE, RAIL = (0x4a, 0x4e, 0x58), (0x20, 0x22, 0x28), (0x5a, 0x5f, 0x6b)

def base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else RAIL if x in (1, 14) or y in (1, 14) else METAL
            im.putpixel((x, y), c + (255,))
    return im

def front(accent, k):
    """A cable socket: dark ring and hole, accent-coloured collar."""
    im = base()
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < 3.0:
                im.putpixel((x, y), (0x0c, 0x0c, 0x10, 255))
            elif d < 4.6:
                im.putpixel((x, y), tuple(int(a * k) for a in accent) + (255,))
            elif d < 5.6:
                im.putpixel((x, y), (0x20, 0x22, 0x28, 255))
    for x in (2, 13):                            # corner bolts
        for y in (2, 13):
            im.putpixel((x, y), (0x38, 0x38, 0x3c, 255))
    return im

def top(accent):
    im = base()
    for x in range(4, 12):                       # accent stripe
        im.putpixel((x, 7), accent + (255,))
        im.putpixel((x, 8), accent + (255,))
    return im

def icon(accent):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in range(2, 14):
        for y in range(2, 14):
            edge = x in (2, 13) or y in (2, 13)
            im.putpixel((x, y), ((0x20, 0x22, 0x28) if edge else (0x5a, 0x5f, 0x6b)) + (255,))
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < 2.4:
                im.putpixel((x, y), (0x0c, 0x0c, 0x10, 255))
            elif d < 4.2:
                im.putpixel((x, y), accent + (255,))
    return im

def write(d, name, accent):
    os.makedirs(f"{root}/{d}/textures", exist_ok=True)
    out = f"{root}/{d}/textures/vaultnet_power_adapter_{name}"
    base().save(f"{root}/{d}/textures/vaultnet_power_adapter_side.png")
    top(accent).save(f"{out}_top.png")
    front(accent, 0.55).save(f"{out}_front.png")
    FR = 8
    strip = Image.new("RGBA", (16, 16 * FR))
    for f in range(FR):
        k = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(2 * math.pi * f / FR))
        strip.paste(front(accent, k), (0, 16 * f))
    strip.save(f"{out}_front_active.png")
    icon(accent).save(f"{out}_icon.png")

write("vaultnet_power_technic", "lv", (0x40, 0xd0, 0x50))
write("vaultnet_power_technic", "mv", (0xf0, 0xb0, 0x20))
write("vaultnet_power_technic", "hv", (0xe0, 0x40, 0x40))
write("vaultnet_power_techage", "ta", (0x40, 0xc0, 0xff))
