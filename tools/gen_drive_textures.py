"""Placeholder drive textures. Usage: gen_drive_textures.py <textures dir>
Writes vaultnet_drives_drive<N>.png (body per tier, no light) and
vaultnet_drives_light<1..5>.png (transparent overlay with the state light,
green -> red)."""
import sys
from PIL import Image

out = sys.argv[1]
import colorsys
TIERS = 10
# grey-blue for tier 1, then a hue sweep for the larger ones
BODIES = [(0x7a, 0x82, 0x90)] + [
    tuple(int(255 * v) for v in colorsys.hsv_to_rgb(0.30 + 0.70 * (i - 1) / (TIERS - 2), 0.55, 0.75))
    for i in range(1, TIERS)]
LIGHTS = [(0x00, 0xc8, 0x00), (0x7f, 0xc8, 0x00), (0xc8, 0xc8, 0x00),
          (0xc8, 0x7f, 0x00), (0xc8, 0x00, 0x00)]

def drive(body):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    dark = tuple(int(c * 0.45) for c in body)
    shade = tuple(int(c * 0.75) for c in body)
    for y in range(2, 15):
        for x in range(3, 13):
            edge = x in (3, 12) or y in (2, 14)
            im.putpixel((x, y), dark + (255,) if edge else body + (255,))
    for x in range(5, 11):            # label
        for y in range(9, 12):
            im.putpixel((x, y), shade + (255,))
    for x in range(5, 11):            # connector
        im.putpixel((x, 13), (0xd8, 0xb0, 0x40, 255))
    return im

for i, body in enumerate(BODIES, 1):
    drive(body).save(f"{out}/vaultnet_drives_drive{i}.png")

for i, c in enumerate(LIGHTS, 1):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in (6, 7, 8, 9):
        for y in (4, 5):
            im.putpixel((x, y), c + (255,))
    im.save(f"{out}/vaultnet_drives_light{i}.png")

# --- drive bay ----------------------------------------------------------
METAL = (0x4a, 0x4e, 0x58)
EDGE = (0x20, 0x22, 0x28)

def bay_base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else METAL
            im.putpixel((x, y), c + (255,))
    return im

def bay_front(led):
    im = bay_base()
    # 4 columns x 2 rows of dark slots; entities draw the drives over them
    for col in range(4):
        for row in range(2):
            for x in range(col * 4 + 1, col * 4 + 3 + (1 if col == 3 else 0)):
                for y in range(row * 7 + 2, row * 7 + 8):
                    im.putpixel((x, y), (0x12, 0x13, 0x16, 255))
    for x in (13, 14):                 # status LED
        im.putpixel((x, 1), led + (255,))
    return im

bay_base().save(f"{out}/vaultnet_drives_bay_side.png")
bay_front((0x30, 0x30, 0x34)).save(f"{out}/vaultnet_drives_bay_front.png")
bay_front((0x20, 0xe0, 0xff)).save(f"{out}/vaultnet_drives_bay_front_active.png")
