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
# Shaped after Refined Storage's Importer/Exporter: a stack of three stepped
# square plates (2, 3 and 5 px half-width, 2 px thick) on the cable-thin core
# (a cable stub runs to every face but the target side). The Exporter's plates
# narrow towards the target (items leave through the tip), the Inserter's
# widen towards it (items are taken in through the wide mouth).
import random
random.seed(7)

def device_frame():
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            g = 0x34 + random.choice((-2, 0, 0, 2))
            if x in (0, 15) or y in (0, 15): g -= 0x0c
            im.putpixel((x, y), (g, g, g, 255))
    return im

device_frame().save(f"{out}/vaultnet_io_device_frame.png")

GREEN, ORANGE = (0x30, 0xe0, 0x70), (0xff, 0x90, 0x20)

def glow_tile(rgb, peak, bright_peak=1.0):
    """Accent band: dim base with a bright ring at row `peak` (None = dim only)."""
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        k = 0.30
        if peak is not None:
            d = min(abs(y - peak), 16 - abs(y - peak))
            k = max(k, bright_peak - d * 0.22)
        for x in range(16):
            im.putpixel((x, y), tuple(int(c * k) for c in rgb) + (255,))
    return im

def glow(rgb, up, name):
    glow_tile(rgb, None).save(f"{out}/vaultnet_io_{name}_glow.png")
    strip = Image.new("RGBA", (16, 16 * 8))
    for f in range(8):
        peak = (15 - 2 * f) if up else (2 * f)      # ring travels along the flow
        strip.paste(glow_tile(rgb, peak), (0, 16 * f))
    strip.save(f"{out}/vaultnet_io_{name}_glow_active.png")

glow(GREEN, True, "inserter")    # flow: target (-Y side) -> network
glow(ORANGE, False, "exporter")  # flow: network -> target

# model: "floor" wallmounted orientation, i.e. attached to the node below, so
# the target is at -Y. Materials (tile order): frame, glow, cable.
def px(v): return (v - 8) / 16.0

def build(kind, path):
    verts, uvs, norms = [], [], []
    faces = {"frame": [], "glow": [], "cable": []}

    def idx(lst, v):
        v = tuple(round(c, 5) for c in v)
        if v not in lst: lst.append(v)
        return lst.index(v) + 1

    def quad(mat, n, pts, uv):
        faces[mat].append([(idx(verts, p), idx(uvs, t), idx(norms, n)) for p, t in zip(pts, uv)])

    def box(x0, y0, z0, x1, y1, z1, side_mat, cap_mat=None, skip=()):
        cap_mat = cap_mat or side_mat
        F = {
            "+x": ((1, 0, 0), [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], side_mat),
            "-x": ((-1, 0, 0), [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], side_mat),
            "+z": ((0, 0, 1), [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], side_mat),
            "-z": ((0, 0, -1), [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], side_mat),
            "+y": ((0, 1, 0), [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], cap_mat),
            "-y": ((0, -1, 0), [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], cap_mat),
        }
        for name, (n, pts, mat) in F.items():
            if name in skip: continue
            if mat == "glow":   # whole tile on each side face
                uv = [(0, 0), (1, 0), (1, 1), (0, 1)]
            elif n[1]:
                uv = [(p[0] + .5, p[2] + .5) for p in pts]
            elif n[0]:
                uv = [(p[2] + .5, p[1] + .5) for p in pts]
            else:
                uv = [(p[0] + .5, p[1] + .5) for p in pts]
            quad(mat, n, pts, uv)

    # plates, listed from the target end (y = -8 px) inwards
    steps = [(-8, -6), (-6, -4), (-4, -2)]
    halves = [2, 3, 5] if kind == "exporter" else [5, 3, 2]
    for (y0, y1), h in zip(steps, halves):
        mat = "glow" if (y0, y1) == (-6, -4) else "frame"
        box(px(8 - h), px(8 + y0), px(8 - h), px(8 + h), px(8 + y1), px(8 + h),
            mat, "frame")

    # cable core and a stub to every face except the target side (-Y)
    c = 2
    box(px(8 - c), px(8 - c), px(8 - c), px(8 + c), px(8 + c), px(8 + c), "cable", skip=("-y",))
    for ax in "xyz":
        for sign in (-1, 1):
            if ax == "y" and sign < 0: continue
            lo = [px(8 - c)] * 3
            hi = [px(8 + c)] * 3
            i = "xyz".index(ax)
            if sign > 0: lo[i], hi[i] = px(8 + c), 0.5
            else: lo[i], hi[i] = -0.5, px(8 - c)
            box(*lo, *hi, "cable")

    with open(path, "w") as f:
        f.write(f"# VaultNet {kind} (generated by tools/gen_io_textures.py)\n")
        for v in verts: f.write("v %g %g %g\n" % v)
        for t in uvs: f.write("vt %g %g\n" % t)
        for nn in norms: f.write("vn %g %g %g\n" % nn)
        for mat in ("frame", "glow", "cable"):
            f.write(f"o {mat}\nusemtl {mat}\n")
            for face in faces[mat]:
                f.write("f " + " ".join("%d/%d/%d" % t for t in face) + "\n")

build("inserter", f"{mod}/models/vaultnet_io_inserter.obj")
build("exporter", f"{mod}/models/vaultnet_io_exporter.obj")
