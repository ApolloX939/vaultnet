"""VaultNet power textures. Usage: gen_power_textures.py <vaultnet_power dir> (needs Pillow)"""
import math, os, random, sys
from PIL import Image

mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)
random.seed(5)

METAL, EDGE, RAIL = (0x4a, 0x4e, 0x58), (0x20, 0x22, 0x28), (0x5a, 0x5f, 0x6b)

def base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else RAIL if x in (1, 14) or y in (1, 14) else METAL
            im.putpixel((x, y), c + (255,))
    return im

base().save(f"{out}/vaultnet_power_side.png")

# generator ------------------------------------------------------------------------
top = base()
for x in range(5, 11):                       # chimney grille
    for y in range(5, 11):
        top.putpixel((x, y), (0x18, 0x1a, 0x1e, 255))
top.save(f"{out}/vaultnet_power_generator_top.png")

def gen_front(flame=None):
    im = base()
    for x in range(3, 13):                   # firebox opening
        for y in range(6, 14):
            im.putpixel((x, y), (0x10, 0x10, 0x12, 255))
    for x in range(4, 12):                   # grate
        im.putpixel((x, 12), (0x38, 0x38, 0x3c, 255))
    if flame:
        for x in range(5, 11):
            h = flame(x)
            for y in range(12 - h, 12):
                t = (12 - y) / max(1, h)
                c = (0xff, int(0xe0 - 0xb0 * t), int(0x40 - 0x30 * t))
                im.putpixel((x, y), c + (255,))
    for x in (13, 14):                       # LED
        im.putpixel((x, 3), ((0xff, 0x90, 0x20) if flame else (0x30, 0x30, 0x34)) + (255,))
    return im

gen_front().save(f"{out}/vaultnet_power_generator_front.png")
FR = 6
strip = Image.new("RGBA", (16, 16 * FR))
for f in range(FR):
    strip.paste(gen_front(lambda x, f=f: 2 + int(2.5 + 2.5 * math.sin(x * 1.3 + f * 1.1))), (0, 16 * f))
strip.save(f"{out}/vaultnet_power_generator_front_active.png")

# solar ------------------------------------------------------------------------------
sol = Image.new("RGBA", (16, 16))
for y in range(16):
    for x in range(16):
        c = (0x14, 0x24, 0x48)
        if x in (0, 15) or y in (0, 15): c = (0x20, 0x22, 0x28)
        elif x % 5 == 0 or y % 5 == 0: c = (0x6a, 0x78, 0x90)
        else:
            k = 0.9 + random.random() * 0.2
            c = tuple(int(v * k) for v in (0x1c, 0x38, 0x78))
        sol.putpixel((x, y), c + (255,))
sol.save(f"{out}/vaultnet_power_solar_top.png")

# icons --------------------------------------------------------------------------------
icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
for x in range(2, 14):
    for y in range(3, 14):
        edge = x in (2, 13) or y in (3, 13)
        icon.putpixel((x, y), ((0x20, 0x22, 0x28) if edge else (0x5a, 0x5f, 0x6b)) + (255,))
for x in range(5, 11):
    for y in range(7, 12):
        icon.putpixel((x, y), (0x10, 0x10, 0x12, 255))
for x in range(6, 10):
    for y in range(9, 12):
        icon.putpixel((x, y), (0xff, 0x90, 0x20, 255))
icon.save(f"{out}/vaultnet_power_generator_icon.png")


# batteries ------------------------------------------------------------------------------
BAT = {"small": (0x60, 0x90, 0xc0), "medium": (0x40, 0xc0, 0xa0), "large": (0xe0, 0xb0, 0x40)}
LEVEL_COLORS = [(0xe0, 0x30, 0x30), (0xf0, 0x90, 0x20), (0xe0, 0xd0, 0x20), (0x90, 0xe0, 0x20), (0x30, 0xe0, 0x40)]

def bat_side(accent):
    im = base()
    for x in range(1, 15):
        for y in (6, 7, 8, 9):
            im.putpixel((x, y), accent + (255,))
    return im

def bat_front(accent, level):
    im = base()
    for y in range(3, 13):                       # cell window
        for x in range(4, 12):
            im.putpixel((x, y), (0x10, 0x12, 0x16, 255))
    for i in range(4):                            # 4 bars, bottom to top
        lit = level >= i + 1
        c = LEVEL_COLORS[min(4, i + 1)] if lit else (0x28, 0x2a, 0x30)
        for y in (10 - i * 2, 11 - i * 2):
            for x in range(5, 11):
                im.putpixel((x, y), c + (255,))
    for x in range(6, 10):                        # terminal cap
        im.putpixel((x, 2), accent + (255,))
    return im

for tier, accent in BAT.items():
    bat_side(accent).save(f"{out}/vaultnet_power_battery_{tier}_side.png")
    top = base()
    for x in range(5, 11):
        for y in range(5, 11):
            top.putpixel((x, y), accent + (255,))
    top.save(f"{out}/vaultnet_power_battery_{tier}_top.png")
    for level in range(5):
        bat_front(accent, level).save(f"{out}/vaultnet_power_battery_{tier}_front{level}.png")
    ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in range(4, 12):
        for y in range(3, 14):
            edge = x in (4, 11) or y in (3, 13)
            ic.putpixel((x, y), ((0x20, 0x22, 0x28) if edge else accent) + (255,))
    for x in range(6, 10):
        ic.putpixel((x, 2), (0xd0, 0xd0, 0xd8, 255))
    ic.save(f"{out}/vaultnet_power_battery_{tier}_icon.png")
