"""VaultNet drives assets. Usage: gen_drive_textures.py <vaultnet_drives dir>  (needs Pillow)

Shaped after Refined Storage's disk drive: a block whose front has 2 columns x 4 rows
of slots, each drive a small flat disk (5x2x1 px) sticking out 1 px with its own LED.

Writes into <dir>/textures and <dir>/models:
  vaultnet_drives_drive<N>.png     inventory icon of tier N (no light)
  vaultnet_drives_light<1..5>.png  icon overlay: the state LED, green -> red
  vaultnet_drives_disk<N>.png      texture of the disk shown in the bay
  vaultnet_drives_led<1..5>.png    flat LED colour of the disk shown in the bay
  vaultnet_drives_bay_frame.png, _slot.png, _slot_active.png (animated)
  vaultnet_drives_bay.obj, vaultnet_drives_disk.obj
Keep the slot layout in sync with bay.lua (SLOT_CENTERS)."""
import colorsys, os, random, sys
from PIL import Image

mod = sys.argv[1]
tex = f"{mod}/textures"
os.makedirs(tex, exist_ok=True)
os.makedirs(f"{mod}/models", exist_ok=True)
random.seed(3)

TIERS = 10
BODIES = [(0x9a, 0xa0, 0xac)] + [
    tuple(int(255 * v) for v in colorsys.hsv_to_rgb(0.30 + 0.70 * (i - 1) / (TIERS - 2), 0.55, 0.85))
    for i in range(1, TIERS)]
LIGHTS = [(0x00, 0xe0, 0x30), (0x90, 0xe0, 0x00), (0xf0, 0xd0, 0x00),
          (0xf0, 0x90, 0x00), (0xe0, 0x20, 0x20)]

def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)

# ---- inventory icons: an RS-style disk seen at an angle ---------------------
def icon(body):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            d = abs(x - 7.5) + abs(y - 7.5)
            if d > 6.6:
                continue
            k = 1.0 + (7.5 - x) * 0.03 + (7.5 - y) * 0.03   # lighter at the top left
            c = shade(body, k)
            if d > 5.6:
                c = shade(body, 0.55)                          # outline
            im.putpixel((x, y), c + (255,))
    for x in range(8, 12):                                     # label slit, lower right
        for y in range(10, 12):
            im.putpixel((x, y), shade(body, 0.62) + (255,))
    return im

for i, body in enumerate(BODIES, 1):
    icon(body).save(f"{tex}/vaultnet_drives_drive{i}.png")

for i, c in enumerate(LIGHTS, 1):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for x in (5, 6):
        for y in (5, 6):
            im.putpixel((x, y), c + (255,))
    im.save(f"{tex}/vaultnet_drives_light{i}.png")

# ---- disk (in the bay) ------------------------------------------------------
for i, body in enumerate(BODIES, 1):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            k = 0.9 + random.random() * 0.1
            if y in (7,): k *= 1.1
            if y in (8,): k *= 0.85
            im.putpixel((x, y), shade(body, k) + (255,))
    im.save(f"{tex}/vaultnet_drives_disk{i}.png")

for i, c in enumerate(LIGHTS, 1):
    Image.new("RGBA", (16, 16), c + (255,)).save(f"{tex}/vaultnet_drives_led{i}.png")

# ---- bay textures -------------------------------------------------------------
frame = Image.new("RGBA", (16, 16))
for y in range(16):
    for x in range(16):
        g = 0x6a + random.choice((-3, 0, 0, 3))
        if x in (0, 15) or y in (0, 15):
            g -= 0x16
        frame.putpixel((x, y), (g, g, g + 4, 255))
for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):             # rivets
    frame.putpixel((x, y), (0x38, 0x38, 0x3c, 255))
frame.save(f"{tex}/vaultnet_drives_bay_frame.png")

SLOT = (0x10, 0x12, 0x16)
Image.new("RGBA", (16, 16), SLOT + (255,)).save(f"{tex}/vaultnet_drives_bay_slot.png")
FR = 12                                                          # active: slow blue pulse behind the drives
strip = Image.new("RGBA", (16, 16 * FR))
import math
for f in range(FR):
    k = 0.5 + 0.5 * math.sin(2 * math.pi * f / FR)
    c = tuple(int(SLOT[j] + ([0x08, 0x50, 0x80][j] * k)) for j in range(3))
    strip.paste(Image.new("RGBA", (16, 16), c + (255,)), (0, 16 * f))
strip.save(f"{tex}/vaultnet_drives_bay_slot_active.png")

# ---- models -------------------------------------------------------------------
def build(path, header, materials, boxes):
    """boxes: (x0,y0,z0,x1,y1,z1, material, {face: (material,)}) in node units."""
    verts, uvs, norms = [], [], []
    faces = {m: [] for m in materials}

    def idx(lst, v):
        v = tuple(round(c, 5) for c in v)
        if v not in lst: lst.append(v)
        return lst.index(v) + 1

    for (x0, y0, z0, x1, y1, z1, mat, over) in boxes:
        F = {
            "+x": ((1, 0, 0), [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)]),
            "-x": ((-1, 0, 0), [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
            "+y": ((0, 1, 0), [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)]),
            "-y": ((0, -1, 0), [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]),
            "+z": ((0, 0, 1), [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]),
            "-z": ((0, 0, -1), [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)]),
        }
        for name, (n, pts) in F.items():
            m = over.get(name, (mat,))[0]
            if n[1]:   uv = [(p[0] + .5, p[2] + .5) for p in pts]
            elif n[0]: uv = [(p[2] + .5, p[1] + .5) for p in pts]
            else:      uv = [(p[0] + .5, p[1] + .5) for p in pts]
            faces[m].append([(idx(verts, p), idx(uvs, t), idx(norms, n)) for p, t in zip(pts, uv)])

    with open(path, "w") as f:
        f.write(f"# {header} (generated by tools/gen_drive_textures.py)\n")
        for v in verts: f.write("v %g %g %g\n" % v)
        for t in uvs: f.write("vt %g %g\n" % t)
        for nn in norms: f.write("vn %g %g %g\n" % nn)
        for m in materials:                                      # material order = tile order
            f.write(f"o {m}\nusemtl {m}\n")
            for face in faces[m]:
                f.write("f " + " ".join("%d/%d/%d" % t for t in face) + "\n")

def X(p): return (p - 8) / 16.0          # px -> node units, x and y
def Z(p): return (p - 8) / 16.0          # z px: 0 = front face (-Z side), 16 = back

# Bay: solid back block, plus a 2 px front layer with 2 x 4 rectangular holes.
HOLE_X = [(1, 7), (9, 15)]
HOLE_Y = [(0.5 + 4 * i, 3.5 + 4 * i) for i in range(4)]
boxes = [(X(0), X(0), Z(2), X(16), X(16), Z(16), "frame", {"-z": ("slot",)})]
# Faces that look into a hole (the hole walls) get the dark "slot" material too,
# so the slots read as dark recesses from any angle.
bars = [(0, 0.5), (3.5, 4.5), (7.5, 8.5), (11.5, 12.5), (15.5, 16)]
for n, (y0, y1) in enumerate(bars):
    over = {}
    if n > 0: over["-y"] = ("slot",)          # ceiling of the hole below
    if n < len(bars) - 1: over["+y"] = ("slot",)   # floor of the hole above
    boxes.append((X(0), X(y0), Z(0), X(16), X(y1), Z(2), "frame", over))
for y0, y1 in HOLE_Y:
    for x0, x1, over in ((0, 1, {"+x": ("slot",)}),
                         (7, 9, {"-x": ("slot",), "+x": ("slot",)}),
                         (15, 16, {"-x": ("slot",)})):
        boxes.append((X(x0), X(y0), Z(0), X(x1), X(y1), Z(2), "frame", over))
build(f"{mod}/models/vaultnet_drives_bay.obj", "VaultNet drive bay", ["frame", "slot"],
      boxes)

# Disk: 5 x 2 x 1 px slab, centred on the origin (symmetric in z, so the entity's
# yaw only has to be right to within 180 degrees), LED at its right end.
S = 1 / 16.0
disk = [
    (-2.5 * S, -1 * S, -0.5 * S, 2.5 * S, 1 * S, 0.5 * S, "disk", {}),
    (1.5 * S, -0.5 * S, -0.55 * S, 2.5 * S, 0.5 * S, 0.55 * S, "led", {}),
]
build(f"{mod}/models/vaultnet_drives_disk.obj", "VaultNet disk", ["disk", "led"], disk)
