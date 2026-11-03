"""VaultNet IO assets. Usage: gen_io_textures.py <vaultnet_io dir>  (needs Pillow)
Writes textures/ (terminal, inserter, exporter) and models/vaultnet_io_device.obj."""
import os, sys
from PIL import Image
mod = sys.argv[1]
out = f"{mod}/textures"
os.makedirs(out, exist_ok=True)
os.makedirs(f"{mod}/models", exist_ok=True)

METAL, EDGE, RAIL = (0x4a, 0x4e, 0x58), (0x20, 0x22, 0x28), (0x5a, 0x5f, 0x6b)

def base():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            c = EDGE if x in (0, 15) or y in (0, 15) else RAIL if x in (1, 14) or y in (1, 14) else METAL
            im.putpixel((x, y), c + (255,))
    return im

base().save(f"{out}/vaultnet_io_terminal_side.png")

def front(lines, fg, bg=(0x08, 0x0c, 0x12)):
    """Screen with text-like lines; `lines` = list of (row, length)."""
    im = base()
    for y in range(3, 13):
        for x in range(3, 13):
            im.putpixel((x, y), bg + (255,))
    for row, length in lines:
        for x in range(4, 4 + length):
            im.putpixel((x, 4 + row), fg + (255,))
    for x in (11, 12):                         # power LED
        im.putpixel((x, 14), fg + (255,))
    return im

DIM = (0x30, 0x38, 0x44)
front([(0, 5), (2, 3), (4, 6)], DIM).save(f"{out}/vaultnet_io_terminal_front.png")

# active: text lines scroll upward, blue
BLUE = (0x30, 0xb0, 0xff)
PATTERN = [6, 3, 5, 0, 4, 6, 2, 0, 5, 4, 0, 6]    # line lengths (0 = blank row)
FRAMES = len(PATTERN)
strip = Image.new("RGBA", (16, 16 * FRAMES))
for f in range(FRAMES):
    lines = [(r, PATTERN[(f + r) % FRAMES]) for r in range(8)]
    strip.paste(front([l for l in lines if l[1] > 0], BLUE), (0, 16 * f))
strip.save(f"{out}/vaultnet_io_terminal_front_active.png")


# ---- inserter / exporter -------------------------------------------------
def device_frame(accent):
    im = base()
    for x in range(2, 14):                 # accent stripe
        im.putpixel((x, 7), accent + (255,))
        im.putpixel((x, 8), accent + (255,))
    return im

GREEN, ORANGE = (0x30, 0xe0, 0x70), (0xff, 0x90, 0x20)
device_frame(GREEN).save(f"{out}/vaultnet_io_inserter_frame.png")
device_frame(ORANGE).save(f"{out}/vaultnet_io_exporter_frame.png")

def chevrons(rgb, shift, up, bright=1.0):
    """Chevron band. up=True: points up (flow away from the target)."""
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            dx = int(abs(x - 7.5) * 0.7)
            v = (y - dx + shift) if up else (y + dx - shift)
            lit = v % 8 in (0, 1)
            c = tuple(int(ch * bright) for ch in rgb) if lit else (0x10, 0x12, 0x16)
            im.putpixel((x, y), c + (255,))
    return im

def band(rgb, up, name):
    chevrons(rgb, 0, up, 0.35).save(f"{out}/vaultnet_io_{name}_glow.png")
    strip = Image.new("RGBA", (16, 16 * 8))
    for f in range(8):
        strip.paste(chevrons(rgb, f, up), (0, 16 * f))
    strip.save(f"{out}/vaultnet_io_{name}_glow_active.png")

band(GREEN, True, "inserter")    # items flow from the target up into the network
band(ORANGE, False, "exporter")  # items flow from the network down into the target

# model: designed for the "floor" wallmounted orientation, i.e. attached to the
# node below, so the target is at -Y. Material order: frame (tile 1), glow (tile 2).
verts, uvs, norms, faces = [], [], [], {"frame": [], "glow": []}

def idx(lst, v):
    v = tuple(round(c, 5) for c in v)
    if v not in lst:
        lst.append(v)
    return lst.index(v) + 1

def quad(mat, n, pts, uv):
    faces[mat].append([(idx(verts, p), idx(uvs, t), idx(norms, n)) for p, t in zip(pts, uv)])

def side_quads(x0, y0, z0, x1, y1, z1, mat, uvf):
    return [
        ((1, 0, 0), [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)]),
        ((-1, 0, 0), [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
        ((0, 0, 1), [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]),
        ((0, 0, -1), [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)]),
    ]

def box(x0, y0, z0, x1, y1, z1):
    for n, pts in side_quads(x0, y0, z0, x1, y1, z1, "frame", None):
        quad("frame", n, pts, [(p[2] + .5 if n[0] else p[0] + .5, p[1] + .5) for p in pts])
    quad("frame", (0, 1, 0), [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
         [(x0 + .5, z1 + .5), (x1 + .5, z1 + .5), (x1 + .5, z0 + .5), (x0 + .5, z0 + .5)])
    quad("frame", (0, -1, 0), [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
         [(x0 + .5, z0 + .5), (x1 + .5, z0 + .5), (x1 + .5, z1 + .5), (x0 + .5, z1 + .5)])

box(-0.4, -0.5, -0.4, 0.4, -0.4, 0.4)      # flange against the target
box(-0.3, -0.4, -0.3, 0.3, 0.3, 0.3)       # body
box(-0.35, 0.3, -0.35, 0.35, 0.4, 0.35)    # cap
G = 0.32
for n, pts in side_quads(-G, -0.2, -G, G, 0.2, G, "glow", None):   # chevron band
    quad("glow", n, pts, [(0, 0), (1, 0), (1, 1), (0, 1)])

with open(f"{mod}/models/vaultnet_io_device.obj", "w") as f:
    f.write("# VaultNet inserter/exporter (generated by tools/gen_io_textures.py)\n")
    for v in verts: f.write("v %g %g %g\n" % v)
    for t in uvs: f.write("vt %g %g\n" % t)
    for nn in norms: f.write("vn %g %g %g\n" % nn)
    for mat in ("frame", "glow"):
        f.write(f"o {mat}\nusemtl {mat}\n")
        for face in faces[mat]:
            f.write("f " + " ".join("%d/%d/%d" % t for t in face) + "\n")
