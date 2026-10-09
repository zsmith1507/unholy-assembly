"""Critters: rabbit, crow, deer, pig, chicken. Drawn in body space, feet on y = 0, facing right."""
import math

from pix import P, add, crop, lerp, mul, scratch, sub, tint


def _r(c, pose_fn, W, H, rot_ang=0.0, centre=False):
    cv = scratch(120, (60, 90), rot_ang)
    pose_fn(cv)
    return crop(cv, W, H, centre=centre or rot_ang != 0.0)


# ---------------------------------------------------------------- rabbit

def _rabbit(c, crouch=0.0, stretch=0.0, ear=0.0, hop=0.0, dead=False):
    # body: an oval, stretched when leaping
    bx = 0.0
    body = c.ellipse((bx, -4.2 + crouch - hop), 5.2 + stretch * 1.5, 3.4 - stretch * 0.6, -0.25 * stretch)
    haunch = c.ellipse((bx - 2.2, -3.6 + crouch * 0.5 - hop), 3.2, 3.2)
    head = c.ellipse((bx + 5.0 + stretch, -6.3 + crouch - hop * 1.1), 2.6, 2.2)
    ear_b = c.capsule((bx + 4.0 + stretch, -7.8 + crouch - hop), (bx + 1.0 - ear + stretch, -12.5 + crouch - hop + ear * 0.6), 0.9, 0.8)
    ear_f = c.capsule((bx + 4.8 + stretch, -8.0 + crouch - hop), (bx + 2.6 - ear + stretch, -13.0 + crouch - hop + ear * 0.8), 1.0, 0.9)
    leg = c.capsule((bx - 2.5, -2.0 - hop), (bx + 0.5 - stretch * 4, -0.4 - hop * 0.3), 1.0, 1.0)
    fore = c.capsule((bx + 3.0, -3.0 - hop), (bx + 3.5 + stretch * 3, -0.5 - hop * 0.6), 0.7, 0.7)
    c.part(ear_b, P["fur_s"], P["fur_s"])
    c.part(leg, P["fur_s"], P["fur_s"])
    c.part(body | haunch | head | fore, P["fur"], P["fur_s"], shade_px=1)
    c.part(ear_f, P["fur"], P["fur_s"], shade_px=1)
    c.paint(c.ellipse((bx - 5.2, -5.0 + crouch - hop), 1.3, 1.2), P["fur_l"])  # cotton tail
    c.paint(c.dot((bx + 5.8 + stretch, -6.8 + crouch - hop)), P["void"] if not dead else P["fur_s"])
    c.paint(c.dot((bx + 7.4 + stretch, -6.0 + crouch - hop)), P["blood_d"])


def rabbit_frames():
    W, H = 22, 18
    out = {}
    out["idle"] = [_r(None, lambda c, k=k: _rabbit(c, crouch=0.3 * k, ear=0.4 * k), W, H) for k in (0, 1, 0, 2)]
    out["walk"] = [_r(None, lambda c, s=s, h=h: _rabbit(c, stretch=s, hop=h), W, H)
                   for s, h in ((0.0, 0.0), (0.6, 1.0), (1.0, 2.0), (0.4, 1.0))]
    out["run"] = [_r(None, lambda c, s=s, h=h: _rabbit(c, stretch=s, hop=h, ear=1.5), W, H)
                  for s, h in ((0.0, 0.0), (0.9, 2.0), (1.4, 3.5), (0.6, 1.5))]
    out["jump"] = [_r(None, lambda c: _rabbit(c, stretch=1.4, hop=0, ear=1.5), W, H)]
    out["fall"] = [_r(None, lambda c: _rabbit(c, stretch=0.4, hop=0, ear=-0.5), W, H)]
    out["hurt"] = [tint(out["idle"][0], (1.3, 0.85, 0.85))]
    out["die"] = [out["idle"][0], _r(None, lambda c: _rabbit(c, crouch=0.8, dead=True), W, H, rot_ang=1.2),
                  _r(None, lambda c: _rabbit(c, dead=True), W, H, rot_ang=math.pi * 0.95)]
    return out


# ---------------------------------------------------------------- crow

def _crow(c, wing=0.0, peck=0.0, fly=False, dead=False):
    """wing: 0 folded, 1 up, -1 down."""
    lift = -3.0 if fly else 0.0
    body = c.ellipse((0, -4.5 + lift), 4.2, 2.7, -0.3 + peck * 0.4)
    tail = c.poly([(-3, -4.5 + lift), (-8, -5.5 + lift), (-8, -3.5 + lift), (-3, -3 + lift)])
    hx, hy = 3.8 + peck * 1.5, -6.6 + lift + peck * 3.5
    head = c.ellipse((hx, hy), 2.1, 1.9)
    beak = c.poly([(hx + 1.5, hy - 0.8), (hx + 4.6, hy + 0.3), (hx + 1.5, hy + 0.9)])
    legs = c.line((0, -2.5 + lift), (-0.5, 0 + lift)) | c.line((1, -2.5 + lift), (1.5, 0 + lift))
    if not fly:
        c.paint(legs, P["ink"])
    c.part(tail, P["feather_s"], P["ink"])
    c.part(body | head, P["feather"], P["feather_s"], shade_px=1, light=P["feather_l"])
    c.part(beak, P["ash"], P["iron_s"], shade_px=1)
    c.paint(c.dot((hx + 0.6, hy - 0.5)), P["bone"] if not dead else P["feather_s"])
    if fly or wing != 0.0:
        ang = -1.2 * wing
        root = (0.5, -5.5 + lift)
        tip = add(root, (-6.0 * math.cos(ang), 7.5 * math.sin(ang) - 1.0))
        mid = lerp(root, tip, 0.5)
        wingm = c.poly([root, add(mid, (-1.5, -1.5)), tip, add(tip, (2.5, 1.5)), add(root, (3.0, 0))])
        c.part(wingm, P["feather_l"], P["feather_s"], shade_px=1)
    else:
        c.part(c.ellipse((-0.8, -4.6 + lift), 3.4, 1.6, -0.2), P["feather_s"], P["ink"], outline=False)


def crow_frames():
    W, H = 24, 22
    out = {}
    out["idle"] = [_r(None, lambda c: _crow(c), W, H), _r(None, lambda c: _crow(c), W, H),
                   _r(None, lambda c: _crow(c, peck=0.2), W, H), _r(None, lambda c: _crow(c, peck=1.0), W, H)]
    out["walk"] = [_r(None, lambda c, p=p: _crow(c, peck=p), W, H) for p in (0.0, 0.25, 0.0, 0.15)]
    out["run"] = [_r(None, lambda c, w=w: _crow(c, wing=w, fly=True), W, H) for w in (1.0, 0.3, -0.8, 0.0)]
    out["jump"] = [_r(None, lambda c: _crow(c, wing=1.0, fly=True), W, H)]
    out["fall"] = [_r(None, lambda c, w=w: _crow(c, wing=w, fly=True), W, H) for w in (0.4, -0.4)]
    out["work"] = [_r(None, lambda c, p=p: _crow(c, peck=p), W, H) for p in (0.0, 1.0, 0.6, 1.0)]
    out["hurt"] = [tint(out["idle"][0], (1.3, 0.85, 0.85))]
    out["die"] = [_r(None, lambda c: _crow(c, wing=0.6, fly=True), W, H),
                  _r(None, lambda c: _crow(c, wing=-0.5, dead=True), W, H, rot_ang=1.6),
                  _r(None, lambda c: _crow(c, dead=True), W, H, rot_ang=math.pi)]
    return out


# ---------------------------------------------------------------- deer (and pig, from the same quadruped)

def _quad(c, k, phase=0.0, gait=0.0, head_down=0.0, dead=False):
    """A lanky quadruped. k: proportions and colours. gait: leg swing amplitude."""
    L, bl, bh = k["leg"], k["body_len"], k["body_h"]
    hip = (-bl * 0.5, -L - bh * 0.3)
    sho = (bl * 0.5, -L - bh * 0.35)
    s = math.sin(phase)
    s2 = math.sin(phase + math.pi)

    def leg(top, sw, near):
        knee = add(top, (sw * L * 0.35, L * 0.5))
        foot = add(knee, (sw * L * 0.15 - abs(sw) * 1.0, L * 0.5 - abs(sw) * 0.5))
        m = c.capsule(top, knee, k["leg_r"] + 0.6, k["leg_r"]) | c.capsule(knee, foot, k["leg_r"], k["leg_r"] * 0.8)
        hoof = c.capsule(add(foot, (0, -1.5)), foot, k["leg_r"] * 0.9, k["leg_r"] * 0.9)
        col, sh = (k["c"], k["s"]) if near else (k["s"], P["ink"])
        c.part(m, col, sh, shade_px=1)
        c.part(hoof, k["hoof"], P["ink"], outline=False)

    leg(add(hip, (-1, 0)), gait * s2, False)
    leg(add(sho, (-1, 0)), gait * s, False)
    body = c.ellipse(lerp(hip, sho, 0.5), bl * 0.62, bh * 0.55)
    rump = c.ellipse(add(hip, (0, -0.5)), bh * 0.5, bh * 0.55)
    chest = c.ellipse(add(sho, (0, 0.5)), bh * 0.5, bh * 0.6)
    c.part(body | rump | chest, k["c"], k["s"], shade_px=2)
    c.paint(c.ellipse(add(lerp(hip, sho, 0.5), (0, bh * 0.38)), bl * 0.45, bh * 0.16), k.get("belly", k["c"]))
    leg(hip, gait * s, True)
    leg(sho, gait * s2, True)
    # neck and head
    nb = add(sho, (bh * 0.2, -bh * 0.2))
    hd = add(nb, (k["neck"] * 0.45 + head_down * 0.5, -k["neck"] + head_down * k["neck"] * 1.6))
    if k["neck"] > 0:
        c.part(c.capsule(nb, hd, bh * 0.38, bh * 0.25), k["c"], k["s"], shade_px=1)
    head = c.ellipse(hd, k["head_r"] * 1.1, k["head_r"] * 0.85, 0.35 + head_down * 0.8)
    snout = c.capsule(hd, add(hd, (k["snout"], k["head_r"] * 0.5 + head_down * 2)), k["head_r"] * 0.65, k["head_r"] * 0.5)
    c.part(head | snout, k["c"], k["s"], shade_px=1)
    c.paint(c.dot(add(hd, (k["head_r"] * 0.35, -k["head_r"] * 0.2))), P["void"] if not dead else k["s"])
    c.paint(c.dot(add(hd, (k["snout"] + k["head_r"] * 0.4, k["head_r"] * 0.45 + head_down * 2))), P["void"])
    if k.get("ears"):
        ear = c.capsule(add(hd, (-k["head_r"] * 0.6, -k["head_r"] * 0.5)), add(hd, (-k["head_r"] * 1.6, -k["head_r"] * 1.4)), 1.0, 0.7)
        c.part(ear, k["c"], k["s"], shade_px=1)
    if k.get("antlers"):
        a0 = add(hd, (-k["head_r"] * 0.3, -k["head_r"] * 0.7))
        m = c.line(a0, add(a0, (-2, -6))) | c.line(add(a0, (-1, -3)), add(a0, (2, -6))) | \
            c.line(add(a0, (-2, -6)), add(a0, (-5, -8))) | c.line(add(a0, (-2, -6)), add(a0, (-1, -10))) | \
            c.line(add(a0, (-1.5, -4.5)), add(a0, (-5, -5)))
        c.paint(m, P["bone_s"])
    if k.get("tail") == "deer":
        c.part(c.capsule(add(hip, (-bh * 0.4, -bh * 0.3)), add(hip, (-bh * 0.65, -bh * 0.05)), 1.2, 0.9), P["fur_l"], k["s"], shade_px=1)
    elif k.get("tail") == "curl":
        c.paint(c.line(add(hip, (-bh * 0.5, -bh * 0.2)), add(hip, (-bh * 0.8, -bh * 0.5))) | c.dot(add(hip, (-bh * 0.65, -bh * 0.65))), k["s"])


DEER = dict(leg=16, body_len=16, body_h=9, neck=9, head_r=2.6, snout=3.5, leg_r=1.1, c=P["deer"], s=P["deer_s"],
            belly=(138, 110, 80, 255), hoof=P["ink"], ears=True, antlers=True, tail="deer")
PIG = dict(leg=6, body_len=13, body_h=10, neck=0, head_r=3.6, snout=3.0, leg_r=1.5, c=P["pig"], s=P["pig_s"],
           hoof=P["leather_s"], ears=True, tail="curl")


def _quad_frames(k, W, H, grazing="work"):
    out = {}
    out["idle"] = [_r(None, lambda c, h=h: _quad(c, k, head_down=h), W, H) for h in (0.0, 0.0, 0.05, 0.0)]
    out["walk"] = [_r(None, lambda c, i=i: _quad(c, k, phase=i * math.pi / 3, gait=0.6), W, H) for i in range(6)]
    out["run"] = [_r(None, lambda c, i=i: _quad(c, k, phase=i * math.pi / 2, gait=1.3), W, H) for i in range(4)]
    out[grazing] = [_r(None, lambda c, h=h: _quad(c, k, head_down=h), W, H) for h in (0.6, 1.0, 1.0, 0.8)]
    out["jump"] = [_r(None, lambda c: _quad(c, k, phase=math.pi / 2, gait=1.4), W, H)]
    out["fall"] = [_r(None, lambda c: _quad(c, k, phase=-math.pi / 2, gait=1.0), W, H)]
    out["hurt"] = [tint(out["idle"][0], (1.3, 0.85, 0.85))]
    out["die"] = [_r(None, lambda c: _quad(c, k, gait=0.4, head_down=-0.2), W, H),
                  _r(None, lambda c: _quad(c, k, gait=0.5, dead=True), W, H, rot_ang=-0.5),
                  _r(None, lambda c: _quad(c, k, gait=0.3, head_down=0.6, dead=True), W, H, rot_ang=math.pi)]
    return out


def deer_frames():
    return _quad_frames(DEER, 48, 48)


def pig_frames():
    return _quad_frames(PIG, 34, 30)


# ---------------------------------------------------------------- chicken (a farm hen, scruffy)

def _hen(c, peck=0.0, step=0.0, flap=0.0, dead=False):
    body = c.ellipse((0, -6), 4.4, 3.6, -0.15)
    tail = c.poly([(-3, -7), (-6.5, -11), (-5.5, -6.5), (-3, -4.5)])
    hx, hy = 3.4 + peck * 2, -10 + peck * 6
    head = c.ellipse((hx, hy), 1.9, 2.0)
    legs = c.line((-0.5, -2.5), (-0.5 - step, 0)) | c.line((1, -2.5), (1 + step, 0))
    c.paint(legs, P["beak"])
    c.part(tail, P["hen_s"], P["ink"])
    c.part(body | head | c.capsule((2, -8), (hx, hy), 1.6, 1.4), P["hen"], P["hen_s"], shade_px=1)
    c.part(c.poly([(hx + 1.5, hy - 0.5), (hx + 3.6, hy + 0.3), (hx + 1.5, hy + 1)]), P["beak"], P["straw_s"])
    c.paint(c.line((hx - 0.5, hy - 2.2), (hx + 1, hy - 2.4)) | c.dot((hx + 1.6, hy + 1.6)), P["comb"])
    c.paint(c.dot((hx + 0.6, hy - 0.5)), P["void"] if not dead else P["hen_s"])
    w = c.ellipse((-0.5, -6.5 - flap * 2), 3.0, 1.8 + flap, -0.2 - flap * 0.8)
    c.part(w, P["hen_s"], P["ash"], outline=flap > 0)


def chicken_frames():
    W, H = 20, 20
    out = {}
    out["idle"] = [_r(None, lambda c, p=p: _hen(c, peck=p), W, H) for p in (0.0, 0.0, 0.1, 0.0)]
    out["walk"] = [_r(None, lambda c, s=s: _hen(c, step=s), W, H) for s in (1.0, 0.0, -1.0, 0.0)]
    out["run"] = [_r(None, lambda c, s=s, f=f: _hen(c, step=s, flap=f), W, H) for s, f in ((1.5, 1.0), (0, 0.2), (-1.5, 1.0), (0, 0.2))]
    out["work"] = [_r(None, lambda c, p=p: _hen(c, peck=p), W, H) for p in (0.0, 1.0, 0.7, 1.0)]
    out["jump"] = [_r(None, lambda c: _hen(c, flap=1.0), W, H)]
    out["fall"] = [_r(None, lambda c, f=f: _hen(c, flap=f), W, H) for f in (1.0, 0.2)]
    out["hurt"] = [tint(out["idle"][0], (1.3, 0.85, 0.85))]
    out["die"] = [_r(None, lambda c: _hen(c, flap=1.0), W, H), _r(None, lambda c: _hen(c, dead=True), W, H, rot_ang=1.4),
                  _r(None, lambda c: _hen(c, dead=True), W, H, rot_ang=math.pi)]
    return out
