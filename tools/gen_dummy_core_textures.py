import sys
from PIL import Image
out = sys.argv[1]

def tile(glow, edge=(0x20,0x22,0x28), body=(0x4a,0x4e,0x58)):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = edge if x in (0,15) or y in (0,15) else body
            if 4 <= x <= 11 and 4 <= y <= 11:
                c = glow
            im.putpixel((x, y), c + (255,))
    return im

tile((0x30,0x30,0x34)).save(f"{out}/vaultnet_core_dummy.png")

frames = 8
strip = Image.new("RGBA", (16, 16 * frames))
pulse = [0.4, 0.55, 0.7, 0.85, 1.0, 0.85, 0.7, 0.55]
for f in range(frames):
    k = pulse[f]
    glow = (int(0x20 * k), int(0xe0 * k), int(0xff * k))
    strip.paste(tile(glow, body=(0x4a,0x4e,0x58)), (0, 16 * f))
strip.save(f"{out}/vaultnet_core_dummy_active.png")
