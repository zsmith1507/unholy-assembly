"""Lair machines, items and magic: heart, grinder, stitching table, altar, spike trap, soul orb, lair items.
Each machine fills the Lair department's footprint (game/lair/builder.gd footprint()) with its base on the
bottom row, so the sprite sits exactly on the box the builder places. Body space: origin at the middle of the
bottom edge, +y down."""
import math

from pix import P, Frame, add, crop, mul, scratch, tint
import numpy as np


def _cv(size=140):
    return scratch(size, (size // 2, size - 20))


def _fit(c, W, H):
    return crop(c, W, H)


def _glow_px(c, mask, color, alpha=255):
    c.glow[mask] = (color[0], color[1], color[2], alpha)


# ---------------------------------------------------------------- the necrotic heart (40 x 48)

HEART_C = (36, 64, 63, 255)   # dead muscle, teal-grey
HEART_S = (22, 40, 42, 255)

def _heart(c, beat=0.0, flick=0):
    """A swollen dead heart on a cradle of ribs, laced with teal veins. beat 0..1 swells it."""
    s = 1.0 + 0.07 * beat
    # cradle: a ribcage of bone curling up from a skull-and-stone base
    base = c.poly([(-17, 0), (17, 0), (14, -6), (-14, -6)])
    c.part(base, P["dark_stone"], P["stone_s"], shade_px=1)
    for x in (-10, -3, 4, 11):
        c.paint(c.line((x, -2), (x + 2, -2)), P["stone_s"])
    ribs = np.zeros((c.h, c.w), bool)
    for k, side in ((0, -1), (1, -1), (0, 1), (1, 1)):
        x0 = side * (6 + k * 5)
        ribs |= c.chain([(x0, -6), (side * (13 + k * 2), -14 - k * 4), (side * (11 + k), -24 - k * 6)], [1.2, 1.1, 0.8])
    c.part(ribs, P["bone"], P["bone_s"], shade_px=1)
    # the heart: two lobes and a pointed apex, tilted
    cy = -21.0
    lobe_l = c.ellipse((-5 * s, cy - 4 * s), 8.5 * s, 9 * s, -0.25)
    lobe_r = c.ellipse((5 * s, cy - 2 * s), 8 * s, 10 * s, 0.2)
    apex = c.poly([(-11 * s, cy + 1), (11 * s, cy + 2), (2, cy + 15 * s), (-1, cy + 15 * s)])
    body = lobe_l | lobe_r | apex
    # arteries: stubby tubes out of the top
    art = c.capsule((-4, cy - 10 * s), (-6, cy - 16 * s), 2.6, 2.2) | c.capsule((3, cy - 11 * s), (5, cy - 17 * s), 2.4, 2.0)
    art |= c.capsule((7, cy - 8 * s), (13, cy - 14 * s), 1.8, 1.5)
    c.part(art, P["flesh"], P["flesh_s"], shade_px=1)
    for p in ((-6, cy - 16 * s), (5, cy - 17 * s), (13, cy - 14 * s)):
        c.paint(c.ellipse(p, 1.2, 0.9), P["void"])
    c.part(body, HEART_C, HEART_S, shade_px=2, light=P["heart"])
    # veins: teal, glowing; brighter on the beat
    vc = P["teal"] if beat > 0.5 else P["teal_m"]
    veins = [
        [(-4, cy - 10), (-5, cy - 4), (-3, cy + 2), (0, cy + 9)],
        [(3, cy - 10), (4, cy - 3), (2, cy + 4)],
        [(-5, cy - 4), (-10, cy - 1)],
        [(4, cy - 3), (9, cy + 1), (7, cy + 6)],
        [(-3, cy + 2), (-7, cy + 5)],
    ]
    for v in veins:
        for a, b in zip(v, v[1:]):
            m = c.line(mul(a, 1), mul(b, 1)) & body
            c.paint(m, vc, P["teal"])
    # a few stitches, the necromancer's own repairs
    for i in range(3):
        y = cy - 6 + i * 3
        c.paint(c.line((8, y), (10, y + 1)) & body, P["stitch"])
    # flickering motes
    rng = [(-12, -34), (14, -38), (-15, -29), (11, -31)]
    for i, p in enumerate(rng):
        if (i + flick) % 3 == 0:
            m = c.dot((p[0], p[1] - flick % 2))
            c.paint(m, P["teal"], P["teal"])
    glowing = c.glow[..., 3] > 0
    c.halo(glowing, P["teal_m"], 60 + int(50 * beat))


def heart_frames():
    W, H = 40, 48
    beats = [0.0, 0.6, 1.0, 0.5, 0.15, 0.0]
    idle = []
    for i, b in enumerate(beats):
        c = _cv()
        _heart(c, b, i)
        idle.append(_fit(c, W, H))
    return {"idle": idle, "work": idle, "hurt": [tint(idle[0], (1.4, 0.8, 0.8))]}


# ---------------------------------------------------------------- the corpse grinder (48 x 48)

def _grinder(c, t=0, working=False):
    # legs and a drip tray
    legs = c.poly([(-19, 0), (-15, 0), (-15, -12), (-18, -12)]) | c.poly([(15, 0), (19, 0), (18, -12), (15, -12)])
    c.part(legs, P["wood"], P["wood_s"], shade_px=1)
    tray = c.poly([(-8, 0), (8, 0), (7, -3), (-7, -3)])
    c.part(tray, P["iron_s"], P["dark_stone"], shade_px=1)
    c.paint(c.poly([(-6, -1), (6, -1), (6, -2), (-6, -2)]), P["blood_d"])
    # body: a riveted iron drum with a wooden frame
    drum = c.poly([(-17, -11), (16, -11), (16, -29), (-17, -29)])
    c.part(drum, P["iron_s"], P["dark_stone"], shade_px=2, light=P["iron"])
    for x in (-15, -5, 5, 15):
        for y in (-13, -27):
            c.paint(c.dot((x, y)), P["iron"])
    bands = c.poly([(-17, -18), (17, -18), (17, -21), (-17, -21)])
    c.paint(bands & ~c.dot((0, -19)), P["rust"])
    # chute spilling out of the bottom
    chute = c.poly([(-4, -11), (4, -11), (3, -6), (-3, -6)])
    c.part(chute, P["iron_s"], P["dark_stone"], shade_px=1)
    if working:
        drip = c.line((0, -6), (0, -4 + (t % 2)))
        c.paint(drip | c.dot(((t % 3) - 1, -3)), P["blood"])
    # blood streaks down the drum
    for x, l in ((-9, 6), (-2, 9), (8, 4), (12, 7)):
        c.paint(c.line((x, -29), (x, -29 + l)), P["blood_d"])
        c.paint(c.dot((x, -29 + l)), P["blood"])
    # hopper: a wide funnel of planks with teeth in its mouth
    hop = c.poly([(-21, -43), (21, -43), (13, -29), (-13, -29)])
    c.part(hop, P["wood"], P["wood_s"], shade_px=2)
    for x in (-12, -4, 4, 12):
        c.paint(c.line((x * 1.4, -42), (x, -30)), P["wood_s"])
    rim = c.poly([(-22, -44), (22, -44), (22, -42), (-22, -42)])
    c.part(rim, P["iron_s"], P["dark_stone"], shade_px=1)
    mouth = c.poly([(-17, -41), (17, -41), (11, -31), (-11, -31)])
    c.paint(mouth, P["void"])
    # two rows of teeth that turn
    off = (t % 4) * 2
    for row, y in ((0, -37), (1, -33)):
        for k in range(-5, 6):
            x = k * 3.2 + ((off if row == 0 else -off) % 3.2) - 1.6
            if abs(x) < (14 if row == 0 else 10):
                tooth = c.poly([(x - 1.2, y + 2), (x + 1.2, y + 2), (x, y - 1.5)]) if row == 0 else \
                    c.poly([(x - 1.2, y - 2), (x + 1.2, y - 2), (x, y + 1.5)])
                c.paint(tooth, P["iron"] if k % 2 else P["bone_s"])
    if working:
        # a hand going in, and a spray of gore
        if t % 4 in (0, 1):
            arm = c.capsule((-4 + t, -45), (-1 + t, -38), 1.6, 1.4)
            c.part(arm, P["skin"], P["skin_s"], shade_px=1)
        for i in range(4):
            a = (t * 1.7 + i * 1.3)
            p = (math.cos(a) * (6 + i * 2), -42 - (i + t) % 3)
            c.paint(c.dot(p), P["gore"] if i % 2 else P["blood"])
    # crank wheel on the side
    wc = (15.5, -20)
    wheel = c.ellipse(wc, 5.5, 5.5)
    c.part(wheel & ~c.ellipse(wc, 3.6, 3.6), P["iron"], P["iron_s"], shade_px=1)
    ang = t * (math.pi / 4) if working else 0.3
    for k in range(3):
        a = ang + k * 2 * math.pi / 3
        c.paint(c.line(wc, add(wc, (math.cos(a) * 4.5, math.sin(a) * 4.5))), P["iron_s"])
    hub = add(wc, (math.cos(ang) * 4.5, math.sin(ang) * 4.5))
    handle = c.capsule(hub, add(hub, (1.5, 0)), 0.8, 0.8)
    c.part(handle, P["wood"], P["wood_s"], shade_px=0)


def grinder_frames():
    W, H = 48, 48
    idle = []
    for i in range(2):
        c = _cv()
        _grinder(c, i * 2, False)
        idle.append(_fit(c, W, H))
    work = []
    for i in range(4):
        c = _cv()
        _grinder(c, i, True)
        work.append(_fit(c, W, H))
    return {"idle": idle, "work": work}


# ---------------------------------------------------------------- the stitching table (56 x 32)

def _table(c, t=0, working=False):
    # trestle legs with cross brace
    for x in (-23, 19):
        c.part(c.poly([(x, 0), (x + 4, 0), (x + 3, -14), (x + 1, -14)]), P["wood"], P["wood_s"], shade_px=1)
    c.paint(c.line((-20, -4), (20, -10)) | c.line((-20, -10), (20, -4)), P["wood_s"])
    # a bucket of thread and spare parts under it
    bucket = c.poly([(-9, 0), (-1, 0), (0, -7), (-10, -7)])
    c.part(bucket, P["wood_s"], P["leather_s"], shade_px=1)
    c.paint(c.line((-9, -7), (-1, -7)), P["blood_d"])
    c.part(c.capsule((-7, -8), (-3, -11), 1.0, 0.8), P["bone"], P["bone_s"], shade_px=0)
    # slab top
    top = c.poly([(-26, -14), (26, -14), (26, -18), (-26, -18)])
    c.part(top, P["wood"], P["wood_s"], shade_px=1, light=P["straw_s"])
    c.paint(c.line((-26, -16), (26, -16)) & top, P["wood_s"])
    c.paint(c.poly([(-6, -15), (12, -15), (10, -14), (-4, -14)]), P["blood_d"])
    # leather straps
    for x in (-14, 2, 16):
        c.paint(c.line((x, -18), (x, -14)), P["leather_s"])
    # an oil lamp post at the head end, the bone saw at the foot
    c.part(c.capsule((-24, -18), (-24, -26), 0.7, 0.7), P["iron_s"], P["iron_s"], shade_px=0)
    lamp = c.ellipse((-24, -27.5), 1.8, 1.5)
    c.part(lamp, P["amber"], P["rust"], shade_px=0)
    c.paint(c.dot((-24, -28)), P["paper"], P["amber"])
    c.halo(c.dot((-24, -28)), P["amber"], 90)
    saw = c.poly([(19, -18), (25, -18), (25, -20), (19, -20)])
    c.part(saw, P["iron"], P["iron_s"], shade_px=0)
    c.part(c.capsule((17, -19), (19, -19), 1.0, 1.0), P["wood"], P["wood_s"], shade_px=0)
    if working:
        # a stitched body taking shape, mismatched skins
        torso = c.capsule((-12, -21), (4, -21), 3.0, 3.0)
        head = c.ellipse((-17, -21.5), 3.2, 3.0)
        leg = c.capsule((4, -20), (16, -19.5), 1.8, 1.6)
        arm = c.capsule((-9, -18.5), (2, -18.8), 1.4, 1.2)
        c.part(leg, P["ghoul_b"], P["ghoul_bs"], shade_px=1)
        c.part(torso | head, P["ghoul"], P["ghoul_s"], shade_px=1)
        c.part(arm, P["rot"], P["rot_s"], shade_px=0)
        c.paint(c.line((-12, -23), (3, -23)), P["stitch"])
        for x in range(-11, 4, 3):
            c.paint(c.line((x, -24), (x + 1, -22)), P["stitch"])
        c.paint(c.dot((-16, -22)), P["void"])
        # the needle, bobbing on a thread of teal
        nx = -8 + (t % 4) * 4
        ny = -27 + (2 if t % 2 else 0)
        c.paint(c.line((nx, ny), (nx + 1, ny + 3)), P["iron"])
        thr = c.line((nx, ny), (nx - 4, -23))
        c.paint(thr, P["teal_m"], P["teal_m"])
        c.paint(c.dot((nx + 1, ny + 3)), P["teal"], P["teal"])
        c.halo(c.dot((nx + 1, ny + 3)), P["teal_m"], 90)
    else:
        # a folded sheet and the needle stuck in the wood
        sheet = c.poly([(-10, -18), (8, -18), (8, -20), (-10, -20)])
        c.part(sheet, P["linen"], P["linen_s"], shade_px=1)
        c.paint(c.line((12, -22), (13, -18)), P["iron"])
        c.paint(c.line((13, -22), (16, -25)), P["stitch"])


def stitching_table_frames():
    W, H = 56, 32
    c = _cv()
    _table(c)
    idle = [_fit(c, W, H)]
    work = []
    for i in range(4):
        c = _cv()
        _table(c, i, True)
        work.append(_fit(c, W, H))
    return {"idle": idle, "work": work}


# ---------------------------------------------------------------- the reanimation altar (48 x 40)

def _altar(c, t=0, working=False):
    steps = c.poly([(-22, 0), (22, 0), (22, -4), (-22, -4)])
    c.part(steps, P["stone_s"], P["dark_stone"], shade_px=1)
    block = c.poly([(-17, -4), (17, -4), (15, -22), (-15, -22)])
    c.part(block, P["stone"], P["stone_s"], shade_px=2)
    slab = c.poly([(-21, -22), (21, -22), (21, -26), (-21, -26)])
    c.part(slab, P["stone"], P["stone_s"], shade_px=1, light=P["ash"])
    # carved skull on the front, eyes lit
    sk = c.ellipse((0, -15), 5.0, 4.2) | c.poly([(-3, -12), (3, -12), (2, -9), (-2, -9)])
    c.part(sk, P["bone_s"], P["ash"], shade_px=0, outline=False)
    c.paint(c.line((-5, -15), (5, -15)) & ~sk, P["stone_s"])
    lit = working or t % 2 == 0
    for x in (-2, 2):
        eye = c.ellipse((x, -15.5), 1.2, 1.1)
        c.paint(eye, P["teal"] if lit else P["teal_m"], P["teal"] if lit else P["teal_m"])
    c.paint(c.line((-1, -11), (1, -11)), P["void"])
    # cracks and old blood
    c.paint(c.line((-13, -20), (-10, -14)) | c.line((-10, -14), (-12, -8)), P["dark_stone"])
    c.paint(c.line((10, -22), (11, -16)), P["blood_d"])
    c.paint(c.line((-6, -22), (-6, -19)), P["blood_d"])
    # runes along the slab edge
    for i, x in enumerate(range(-18, 19, 6)):
        on = working and (i + t) % 3 != 0
        c.paint(c.line((x, -25), (x + 1, -23)) | c.dot((x + 2, -24)), P["teal"] if on else P["teal_d"],
                P["teal_m"] if on else None)
    # candles at each end, teal flames
    for side in (-1, 1):
        x = side * 18
        cand = c.poly([(x - 1.5, -26), (x + 1.5, -26), (x + 1.5, -31), (x - 1.5, -31)])
        c.part(cand, P["bone"], P["bone_s"], shade_px=1)
        c.paint(c.dot((x + side * 1, -27)), P["bone_s"])
        fl = (t + (0 if side < 0 else 1)) % 3
        flame = c.poly([(x - 1.2, -32), (x + 1.2, -32), (x + (fl - 1) * 0.8, -35.5 - (fl % 2))])
        c.paint(flame, P["teal"], P["teal"])
        c.halo(flame, P["teal_m"], 80)
    if working:
        # a column of teal light rising from the slab with soul motes
        col = c.poly([(-8, -27), (8, -27), (5, -38), (-5, -38)])
        c.glow[col & (c.glow[..., 3] < 70)] = P["teal_m"][:3] + (70,)
        for i in range(5):
            y = -28 - ((t * 3 + i * 4) % 11)
            x = ((i * 5 + t * 2) % 11) - 5
            c.paint(c.dot((x, y)), P["teal"], P["teal"])
        c.halo(c.poly([(-8, -27), (8, -27), (8, -28), (-8, -28)]), P["teal"], 130)


def altar_frames():
    W, H = 48, 40
    idle, work = [], []
    for i in range(3):
        c = _cv()
        _altar(c, i, False)
        idle.append(_fit(c, W, H))
    for i in range(4):
        c = _cv()
        _altar(c, i, True)
        work.append(_fit(c, W, H))
    return {"idle": idle, "work": work}


# ---------------------------------------------------------------- the spike trap (24 x 10)

def _trap(c, armed=True, bloody=False):
    base = c.poly([(-10, 0), (10, 0), (10, -2), (-10, -2)])
    c.part(base, P["wood"], P["wood_s"], shade_px=1)
    h = 6 if armed else 2
    for i, x in enumerate(range(-8, 9, 4)):
        sp = c.poly([(x - 1.2, -2), (x + 1.2, -2), (x, -2 - h)])
        c.part(sp, P["iron"], P["iron_s"], shade_px=1)
        if bloody and i % 2 == 0:
            c.paint(c.line((x, -2 - h), (x, -h + 1)), P["blood"])


def spike_trap_frames():
    W, H = 24, 10
    out = {}
    for name, armed, bloody in (("idle", True, False), ("work", False, True), ("die", False, False)):
        c = _cv(60)
        _trap(c, armed, bloody)
        out[name] = [_fit(c, W, H)]
    # sprung: snap up bloody
    c = _cv(60)
    _trap(c, True, True)
    out["cast"] = [_fit(c, W, H)]
    return out


# ---------------------------------------------------------------- soul orb (10 x 10, floats)

def soul_orb_frames():
    W, H = 12, 14
    idle = []
    for i in range(4):
        c = _cv(40)
        r = 2.6 + (0.4 if i in (1, 2) else 0)
        core = c.ellipse((0, -8), r, r)
        sway = (0, 1, 0, -1)[i]
        tail = c.capsule((0, -6), (sway, -3), 1.8, 1.0) | c.capsule((sway, -3), (-sway, -1), 1.0, 0.5)
        c.paint(tail, P["teal_m"], P["teal_m"])
        c.paint(core, P["teal"], P["teal"])
        c.paint(c.dot((-1, -9)), P["eye_white"], P["eye_white"])
        c.halo(core | tail, P["teal_m"], 120)
        idle.append(crop(c, W, H))
    return {"idle": idle}


# ---------------------------------------------------------------- lair items (lair_item.gd SIZES)

def _shroud(c, L, skin=None, stitched=False):
    """A body lying on its back, head left, wrapped in a shroud (or a stitched ghoul body)."""
    if stitched:
        body = c.capsule((-L / 2 + 5, -4), (L / 2 - 2, -3), 3.3, 2.6)
        c.part(body, P["ghoul"], P["ghoul_s"], shade_px=1)
        leg = c.capsule((2, -2.5), (L / 2 - 1, -2), 1.8, 1.6)
        c.part(leg, P["ghoul_b"], P["ghoul_bs"], shade_px=1)
        head = c.ellipse((-L / 2 + 3, -4.5), 3.0, 3.0)
        c.part(head, P["ghoul"], P["ghoul_s"], shade_px=1)
        c.paint(c.line((-L / 2 + 6, -5), (L / 2 - 4, -5)), P["stitch"])
        for x in range(int(-L / 2 + 7), int(L / 2 - 4), 3):
            c.paint(c.line((x, -6), (x + 1, -4)), P["stitch"])
        c.paint(c.dot((-L / 2 + 3, -5.5)), P["teal_d"])
        c.paint(c.line((-L / 2 + 8, -6.5), (-L / 2 + 8, -6.5)), P["stitch"])
    else:
        body = c.capsule((-L / 2 + 4, -3.5), (L / 2 - 3, -3), 3.2, 2.4)
        c.part(body, P["linen"], P["linen_s"], shade_px=1)
        for x in (-L / 2 + 8, -2, 5, L / 2 - 6):
            c.paint(c.line((x, -6), (x + 1, -1)), P["rag_s"])
        c.paint(c.ellipse((-3, -3), 2.0, 1.2), P["blood_d"])
        feet = c.ellipse((L / 2 - 2, -5), 1.4, 1.6)
        c.part(feet, skin or P["skin"], P["skin_s"], shade_px=0)


def _sack(c, w, h, fill, shade):
    m = c.ellipse((0, -h / 2), w / 2 - 1, h / 2 - 0.5) | c.poly([(-2, -h + 1), (2, -h + 1), (1, -h - 1), (-1, -h - 1)])
    c.part(m, fill, shade, shade_px=1)


def items():
    out = {}
    c = _cv(60); _shroud(c, 22); out["corpse"] = [_fit(c, 26, 8)]
    c = _cv(60); _shroud(c, 22, stitched=True); out["stitched_body"] = [_fit(c, 26, 9)]
    # part: a severed arm, hand curled
    c = _cv(40)
    arm = c.capsule((-2.5, -2.5), (1.5, -2.5), 1.5, 1.3)
    c.part(arm, P["skin"], P["skin_s"], shade_px=1)
    c.part(c.ellipse((2.6, -2.6), 1.3, 1.4), P["skin"], P["skin_s"], shade_px=0)
    c.paint(c.ellipse((-3, -2.5), 0.8, 1.2), P["blood"])
    out["part"] = [_fit(c, 10, 6)]
    # gibs: a lumpy, seeping sack
    c = _cv(40)
    _sack(c, 8, 6, P["rag"], P["rag_s"])
    c.paint(c.ellipse((-1, -2), 2.4, 1.6) & c.ellipse((0, -3.5), 4, 3), P["blood_d"])
    c.paint(c.dot((2, -4)) | c.dot((-2, -5)), P["gore"])
    out["gibs"] = [_fit(c, 10, 8)]
    # bones: three long bones tied with twine
    c = _cv(40)
    for i, y in enumerate((-1.5, -2.8)):
        b = c.capsule((-3.5 + i * 0.5, y), (3.5 - i * 0.5, y + 0.3), 0.7, 0.7)
        b |= c.ellipse((-4 + i * 0.5, y), 1.1, 0.9) | c.ellipse((4 - i * 0.5, y + 0.3), 1.1, 0.9)
        c.part(b, P["bone"], P["bone_s"], shade_px=0, outline=(i == 0))
    c.paint(c.line((0, -6), (0, -1)), P["straw_s"])
    out["bones"] = [_fit(c, 12, 6)]
    # meat: a raw hunk with a bone end
    c = _cv(40)
    m = c.ellipse((-0.5, -2.4), 2.5, 1.8)
    c.part(m, P["flesh"], P["flesh_s"], shade_px=1, light=P["gore"])
    c.part(c.capsule((1.6, -3.0), (2.2, -3.6), 0.7, 0.7), P["bone"], P["bone_s"], shade_px=0)
    out["meat"] = [_fit(c, 8, 6)]
    return {k: {"idle": v} for k, v in out.items()}


SPRITES = {
    "heart": (heart_frames, {"idle": 7.0, "work": 9.0}),
    "grinder": (grinder_frames, {"idle": 2.0, "work": 10.0}),
    "stitching_table": (stitching_table_frames, {"work": 8.0}),
    "altar": (altar_frames, {"idle": 5.0, "work": 9.0}),
    "spike_trap": (spike_trap_frames, {}),
    "soul_orb": (soul_orb_frames, {"idle": 8.0}),
}
