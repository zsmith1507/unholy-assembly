"""Tiny pixel-art toolkit for Unholy Assembly sprites.

Every sprite is drawn back to front as a stack of *parts*. A part is a boolean mask plus a flat colour;
each part gets its own 1 px dark outline, so overlapping limbs get ink lines between them (Darkest
Dungeon's look), and one shadow tone along its back/bottom edge. Emissive pixels (necrotic glow) are
also written to a separate glow layer that the game draws unshaded, so they stay bright in the dark.

Run build_all.py to regenerate everything; output is deterministic.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "sprites"))
RES_DIR = "res://art/sprites"


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# ---------------------------------------------------------------- the palette
# Darkest Dungeon grime on top, cold teal necromancy, purple from the deep.
P = {
    "ink": hexc("0e0a10"),        # outlines
    "void": hexc("070508"),       # inside hoods, mouths
    "bone": hexc("ddd2bf"),
    "bone_s": hexc("a89c88"),
    "ash": hexc("92867c"),
    "blood": hexc("9a2222"),
    "blood_d": hexc("5e1a1a"),
    "gore": hexc("b8433a"),
    # skin
    "skin": hexc("b98f72"),
    "skin_s": hexc("8e664f"),
    "pale": hexc("c8bba4"),       # the necromancer's dead-pale hands
    "pale_s": hexc("948875"),
    "ghoul": hexc("7f8c69"),
    "ghoul_s": hexc("5b6a4b"),
    "ghoul_b": hexc("8f8a72"),    # second skin, for mismatched parts
    "ghoul_bs": hexc("6a6552"),
    "rot": hexc("6e7d5a"),
    "rot_s": hexc("4c5a3e"),
    "stitch": hexc("2a1a1c"),
    # cloth
    "robe": hexc("3b2d4a"),
    "robe_s": hexc("261d31"),
    "robe_t": hexc("5c4872"),     # trim
    "linen": hexc("a89878"),
    "linen_s": hexc("7c6d55"),
    "brown": hexc("6b4e34"),
    "brown_s": hexc("4a3524"),
    "rag": hexc("5a4b3c"),
    "rag_s": hexc("3e3329"),
    "red_cloth": hexc("7a2a26"),
    "red_cloth_s": hexc("561c1a"),
    "green_cloth": hexc("4f5a3a"),
    "green_cloth_s": hexc("374029"),
    "straw": hexc("b8954f"),
    "straw_s": hexc("8a6c36"),
    "hair": hexc("4a3626"),
    "hair_g": hexc("8a8478"),
    "leather": hexc("4b3226"),
    "leather_s": hexc("33221a"),
    "wood": hexc("6a4a2c"),
    "wood_s": hexc("4a321e"),
    "iron": hexc("8a8a90"),
    "iron_s": hexc("5c5c64"),
    "rust": hexc("7a4a2a"),
    "stone": hexc("5a5460"),
    "stone_s": hexc("3e3944"),
    "dark_stone": hexc("2e2a34"),
    "fur": hexc("8a7a66"),
    "fur_s": hexc("665846"),
    "fur_l": hexc("c2b49c"),
    "deer": hexc("7a5a3a"),
    "deer_s": hexc("573f28"),
    "pig": hexc("b08070"),
    "pig_s": hexc("8a5e52"),
    "feather": hexc("26222c"),
    "feather_s": hexc("17141b"),
    "feather_l": hexc("3a3444"),
    "beak": hexc("c9a24a"),
    "hen": hexc("c8c0a8"),
    "hen_s": hexc("948c78"),
    "comb": hexc("a8342c"),
    "paper": hexc("d8cdb0"),
    "paper_s": hexc("a99f86"),
    "eye_white": hexc("e6dccb"),
    "iris": hexc("2f8a7e"),
    # magic
    "teal": hexc("7fe8d8"),
    "teal_m": hexc("3fb8a8"),
    "teal_d": hexc("1d5650"),
    "teal_xd": hexc("12302e"),
    "heart": hexc("2f6e66"),
    "heart_s": hexc("1d4a45"),
    "flesh": hexc("6e2f3a"),
    "flesh_s": hexc("4a1e28"),
    "purple": hexc("8a5ab8"),
    "amber": hexc("c98a3b"),
}


# ---------------------------------------------------------------- geometry helpers

def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def mul(a, k):
    return (a[0] * k, a[1] * k)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def polar(length, ang):
    """A vector of `length` at angle `ang`: 0 = straight down, positive = forward (right)."""
    return (length * math.sin(ang), length * math.cos(ang))


# ---------------------------------------------------------------- the canvas

class Canvas:
    def __init__(self, w, h, xf=None):
        self.w, self.h = w, h
        self.col = np.zeros((h, w, 4), np.uint8)
        self.glow = np.zeros((h, w, 4), np.uint8)
        yy, xx = np.mgrid[0:h, 0:w]
        self._x = xx + 0.5
        self._y = yy + 0.5
        self.xf = xf or (lambda p: p)  # body space -> canvas space (rotation for falls)

    # ---- masks (points pass through self.xf)
    def poly(self, pts):
        pts = [self.xf(p) for p in pts]
        img = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(img).polygon([(round(x - 0.5), round(y - 0.5)) for x, y in pts], fill=1, outline=1)
        return np.array(img, bool)

    def capsule(self, a, b, ra, rb=None):
        """A tapered limb from a (radius ra) to b (radius rb)."""
        rb = ra if rb is None else rb
        a, b = self.xf(a), self.xf(b)
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 < 1e-6:
            t = np.zeros_like(self._x)
        else:
            t = np.clip(((self._x - ax) * dx + (self._y - ay) * dy) / L2, 0, 1)
        px = ax + t * dx
        py = ay + t * dy
        d = np.hypot(self._x - px, self._y - py)
        r = ra + (rb - ra) * t
        return d <= r

    def chain(self, pts, radii):
        m = np.zeros((self.h, self.w), bool)
        for i in range(len(pts) - 1):
            m |= self.capsule(pts[i], pts[i + 1], radii[i], radii[i + 1])
        return m

    def ellipse(self, c, rx, ry, ang=0.0):
        c = self.xf(c)
        # rotation of the ellipse follows the transform's rotation
        probe = sub(self.xf((1000.0, 0.0)), self.xf((0.0, 0.0)))
        ang = ang + math.atan2(probe[1], probe[0])
        x = self._x - c[0]
        y = self._y - c[1]
        cs, sn = math.cos(-ang), math.sin(-ang)
        u = x * cs - y * sn
        v = x * sn + y * cs
        return (u / rx) ** 2 + (v / ry) ** 2 <= 1.0

    def dot(self, p):
        p = self.xf(p)
        m = np.zeros((self.h, self.w), bool)
        x, y = int(math.floor(p[0])), int(math.floor(p[1]))
        if 0 <= x < self.w and 0 <= y < self.h:
            m[y, x] = True
        return m

    def line(self, a, b):
        """A 1 px line, for stitches, tines and cracks."""
        a, b = self.xf(a), self.xf(b)
        m = np.zeros((self.h, self.w), bool)
        n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            x = int(math.floor(a[0] + (b[0] - a[0]) * t))
            y = int(math.floor(a[1] + (b[1] - a[1]) * t))
            if 0 <= x < self.w and 0 <= y < self.h:
                m[y, x] = True
        return m

    # ---- painting
    def part(self, mask, fill, shade=None, outline=True, glow=None, shade_px=2, light=None):
        """Paint a part: outline, flat fill, a shadow band on the back/bottom edge, optional highlight."""
        if not mask.any():
            return
        if outline:
            ring = dilate(mask) & ~mask
            self.col[ring] = P["ink"]
        self.col[mask] = fill
        if shade is not None:
            band = np.zeros_like(mask)
            for k in range(1, shade_px + 1):
                band |= mask & ~shift(mask, k, 0)    # back (left) edge
            band |= mask & ~shift(mask, 0, -1)       # bottom edge
            self.col[band] = shade
        if light is not None:
            hl = mask & ~shift(mask, -1, 0) & shift(mask, 0, 1)  # front (right) edge, not the top
            self.col[hl] = light
        if glow is not None:
            self.glow[mask] = glow

    def paint(self, mask, color, glow=None):
        """Paint without outline (details: eyes, stitches, cracks)."""
        self.col[mask] = color
        if glow is not None:
            self.glow[mask] = glow

    def halo(self, mask, color, alpha=110):
        """Soft glow spill around emissive pixels, on the glow layer only."""
        ring = dilate(dilate(mask, 8)) & ~mask
        c = (color[0], color[1], color[2], alpha)
        sel = ring & (self.glow[..., 3] < alpha)
        self.glow[sel] = c

    def image(self):
        return self.col


def shift(m, dx, dy):
    """m shifted so out[y, x] = m[y + dy, x + dx]... i.e. 'is the neighbour at (dx, dy) set?'"""
    out = np.zeros_like(m)
    h, w = m.shape
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    out[ys0:ys1, xs0:xs1] = m[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
    return out


def dilate(m, n=4):
    out = m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)
    if n == 8:
        out |= shift(m, 1, 1) | shift(m, -1, 1) | shift(m, 1, -1) | shift(m, -1, -1)
    return out


# ---------------------------------------------------------------- frames

class Frame:
    """A finished frame: colour and glow RGBA arrays of the final size."""

    def __init__(self, col, glow):
        self.col = col
        self.glow = glow


def scratch(size=200, anchor=(100, 100), rot_ang=0.0, pivot=(0, 0)):
    """A big scratch canvas in body space (origin at `anchor`), optionally rotated about `pivot`."""

    def xf(p):
        q = sub(p, pivot)
        q = rot(q, rot_ang)
        q = add(q, pivot)
        return (q[0] + anchor[0], q[1] + anchor[1])

    c = Canvas(size, size, xf)
    c.anchor = anchor
    return c


def crop(c, w, h, anchor_x=None, ground=True, dy=0, centre=False):
    """Cut a w x h frame from a scratch canvas: anchor x centred, lowest pixel on the bottom row.
    centre=True centres the drawing's bounding box instead (corpses lying down)."""
    ax = int(c.anchor[0] if anchor_x is None else anchor_x)
    alpha = c.col[..., 3] > 0
    if centre:
        cols = np.where(alpha.any(axis=0))[0]
        if len(cols):
            ax = int((cols.min() + cols.max() + 1) // 2)
    rows = np.where(alpha.any(axis=1))[0]
    bottom = rows.max() if (ground and len(rows)) else int(c.anchor[1])
    y1 = bottom + 1 - dy
    y0 = y1 - h
    x0 = ax - w // 2
    x1 = x0 + w
    full = alpha.sum()
    inside = alpha[max(0, y0):y1, max(0, x0):x1].sum()
    if inside != full:
        print("  warning: %d px clipped" % (full - inside))
    col = np.zeros((h, w, 4), np.uint8)
    glow = np.zeros((h, w, 4), np.uint8)
    sy0, sx0 = max(0, y0), max(0, x0)
    col[sy0 - y0:y1 - y0, sx0 - x0:x1 - x0] = c.col[sy0:y1, sx0:x1]
    glow[sy0 - y0:y1 - y0, sx0 - x0:x1 - x0] = c.glow[sy0:y1, sx0:x1]
    return Frame(col, glow)


def tint(frame, mult):
    """Darken/tint a frame's colour (for hurt flashes)."""
    col = frame.col.astype(np.float32)
    col[..., :3] = np.clip(col[..., :3] * np.array(mult[:3]), 0, 255)
    return Frame(col.astype(np.uint8), frame.glow.copy())


# ---------------------------------------------------------------- output

STANDARD = ["idle", "walk", "run", "jump", "fall", "cast", "work", "carry", "hurt", "die", "swim"]


def write_sprite(name, anims, speeds=None, loops=None, aliases=None):
    """anims: {anim: [Frame]}; aliases: {anim: other_anim}. Writes <name>.png, <name>.tres and,
    if anything glows, <name>_glow.png and <name>_glow.tres with the same layout."""
    speeds = speeds or {}
    loops = loops or {}
    aliases = dict(aliases or {})
    for a in STANDARD:
        if a not in anims and a not in aliases:
            aliases[a] = "idle"
    order = list(anims.keys())
    fw, fh = anims[order[0]][0].col.shape[1], anims[order[0]][0].col.shape[0]
    cols = max(len(v) for v in anims.values())
    sheet = np.zeros((fh * len(order), fw * cols, 4), np.uint8)
    gsheet = np.zeros_like(sheet)
    for r, a in enumerate(order):
        for c, f in enumerate(anims[a]):
            assert f.col.shape[:2] == (fh, fw), (name, a, f.col.shape)
            sheet[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] = f.col
            gsheet[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] = f.glow
    os.makedirs(OUT_DIR, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(OUT_DIR, name + ".png"))
    has_glow = gsheet[..., 3].any()
    layouts = [(name, name + ".png")]
    if has_glow:
        Image.fromarray(gsheet, "RGBA").save(os.path.join(OUT_DIR, name + "_glow.png"))
        layouts.append((name + "_glow", name + "_glow.png"))
    else:
        for stale in (name + "_glow.png", name + "_glow.tres"):
            p = os.path.join(OUT_DIR, stale)
            if os.path.exists(p):
                os.remove(p)
    for res_name, png in layouts:
        _write_tres(res_name, png, order, anims, aliases, speeds, loops, fw, fh)
    return sheet


def _write_tres(res_name, png, order, anims, aliases, speeds, loops, fw, fh):
    subs = []
    ids = {}
    for r, a in enumerate(order):
        for c in range(len(anims[a])):
            sid = "f%d_%d" % (r, c)
            ids[(a, c)] = sid
            subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1")\n'
                        'region = Rect2(%d, %d, %d, %d)\n' % (sid, c * fw, r * fh, fw, fh))
    entries = []
    all_names = order + [a for a in aliases if a not in anims]
    for a in all_names:
        src = a if a in anims else aliases[a]
        n = len(anims[src])
        frames = ", ".join('{"duration": 1.0, "texture": SubResource("%s")}' % ids[(src, c)] for c in range(n))
        loop = loops.get(a, loops.get(src, a not in ("die", "jump")))
        speed = speeds.get(a, speeds.get(src, 6.0))
        entries.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.1f}'
                       % (frames, "true" if loop else "false", a, speed))
    text = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(subs) + 2)
    text += '[ext_resource type="Texture2D" path="%s/%s" id="1"]\n\n' % (RES_DIR, png)
    text += "\n".join(subs)
    text += "\n[resource]\nanimations = [%s]\n" % ", ".join(entries)
    with open(os.path.join(OUT_DIR, res_name + ".tres"), "w") as f:
        f.write(text)


def write_png(name, arr):
    os.makedirs(OUT_DIR, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(os.path.join(OUT_DIR, name + ".png"))
