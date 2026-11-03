"""Placeholder drive textures. Usage: gen_drive_textures.py <textures dir>
Writes vaultnet_drives_drive<N>.png (body per tier, no light) and
vaultnet_drives_light<1..5>.png (transparent overlay with the state light,
green -> red)."""
import sys
from PIL import Image

out = sys.argv[1]
BODIES = [(0x7a, 0x82, 0x90), (0x3f, 0x8f, 0x5a), (0x3a, 0x7f, 0xc0), (0xb0, 0x4a, 0xc8)]
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
