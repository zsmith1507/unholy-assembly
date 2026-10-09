"""Humanoids: the necromancer, ghouls (and rotlings), farmers and villagers."""
import math

from pix import P, add, crop, lerp, mul, polar, scratch, sub, tint, Frame
from rig import Spec, base_pose, solve, walk_pose

TEAL_GLOW = P["teal"]


def _limb(c, a, b, ra, rb, fill, shade):
    c.part(c.capsule(a, b, ra, rb), fill, shade, shade_px=1)


def _arm(c, j, side, spec, fill, shade, hand, hand_s, sleeve=None, sleeve_s=None, hand_r=1.9, glow=None):
    sh, el, ha = (j.shoulder_f, j.elbow_f, j.hand_f) if side == "f" else (j.shoulder_b, j.elbow_b, j.hand_b)
    if sleeve is not None:
        m = c.capsule(sh, el, spec.limb_r + 0.8, spec.limb_r + 0.6) | c.capsule(el, lerp(el, ha, 0.7), spec.limb_r + 0.6, spec.limb_r2 + 1.2)
        c.part(m, sleeve, sleeve_s, shade_px=1)
        hm = c.capsule(lerp(el, ha, 0.65), ha, spec.limb_r2, hand_r)
    else:
        hm = c.capsule(sh, el, spec.limb_r, spec.limb_r) | c.capsule(el, ha, spec.limb_r, spec.limb_r2)
        c.part(hm, fill, shade, shade_px=1)
        hm = c.capsule(lerp(el, ha, 0.85), ha, spec.limb_r2, hand_r)
    c.part(hm, hand, hand_s, shade_px=1)
    if glow is not None:
        tip = add(ha, mul(sub(ha, el), 0.22))
        g = c.capsule(ha, tip, 1.6, 1.0)
        c.paint(g, glow, glow)
        c.halo(g, glow, 150)


def _leg(c, j, side, spec, fill, shade, boot, boot_s):
    hp = j.hip
    kn, an, to = (j.knee_f, j.ankle_f, j.toe_f) if side == "f" else (j.knee_b, j.ankle_b, j.toe_b)
    m = c.capsule(hp, kn, spec.leg_r, spec.leg_r2 + 0.3) | c.capsule(kn, an, spec.leg_r2 + 0.3, spec.leg_r2)
    c.part(m, fill, shade, shade_px=1)
    fm = c.capsule(lerp(kn, an, 0.6), an, spec.leg_r2 + 0.4, spec.leg_r2 + 0.6) | c.capsule(an, to, 1.7, 1.2)
    c.part(fm, boot, boot_s, shade_px=1)


# ---------------------------------------------------------------- the necromancer

NECRO_SPEC = Spec(thigh=14, shin=14, foot=4, torso=19, upper=12, fore=12, head_r=5, hunch=2.5,
                  head_fwd=2.5, chest_r=4.5, hip_r=4.0, limb_r=1.6, limb_r2=1.3, leg_r=1.7, leg_r2=1.4)


def draw_necromancer(c, j, s, phase=0.0, cast=0.0):
    up, back, fwd = j.up, j.back, j.fwd
    # back leg and arm (in shadow behind the robe)
    _leg(c, j, "b", s, P["robe_s"], P["void"], P["leather_s"], P["void"])
    _arm(c, j, "b", s, None, None, P["pale_s"], P["pale_s"], sleeve=P["robe_s"], sleeve_s=P["void"],
         glow=P["teal_m"] if cast > 0 else None)
    # the robe: from the shoulders, flaring to a ragged hem around the shins
    hem_y = max(j.knee_f[1], j.knee_b[1]) + 9
    hem_f = min(max(j.knee_f[0], j.ankle_f[0]) + 2.5, j.hip[0] + 9)
    hem_b = max(min(j.knee_b[0], j.ankle_b[0], j.hip[0] - 6) - 2.5, j.hip[0] - 10) - 1.5 * math.sin(phase)
    neck = j.neck
    pts = [
        add(neck, mul(fwd, 2.5)),
        add(j.chest, mul(fwd, 3.2)),
        add(j.hip, mul(fwd, 3.0)),
        (hem_f, hem_y - 1),
        (hem_f - 2, hem_y + 1),
        (lerp((hem_b, 0), (hem_f, 0), 0.66)[0], hem_y - 1),
        (lerp((hem_b, 0), (hem_f, 0), 0.5)[0], hem_y + 2),
        (lerp((hem_b, 0), (hem_f, 0), 0.3)[0], hem_y),
        (hem_b + 1, hem_y + 2),
        (hem_b, hem_y - 2),
        add(j.hip, mul(back, 5.0)),
        add(j.chest, mul(back, 4.5)),
        add(neck, mul(back, 3.5)),
    ]
    robe = c.poly(pts)
    c.part(robe, P["robe"], P["robe_s"], shade_px=2)
    # a front fold line and a bone clasp of finger bones
    fold = c.line(add(j.chest, mul(fwd, 0.5)), (lerp((hem_b, 0), (hem_f, 0), 0.55)[0], hem_y - 2))
    c.paint(fold, P["robe_s"])
    # belt of rope with a dangling skull charm
    belt = c.capsule(add(j.hip, mul(back, 4.5)), add(j.hip, mul(fwd, 3.0)), 0.8, 0.8)
    c.paint(belt, P["robe_t"])
    charm = c.ellipse(add(add(j.hip, mul(fwd, 2.0)), (0, 3.5)), 1.4, 1.6)
    c.part(charm, P["bone"], P["bone_s"], shade_px=1)
    # front leg below the hem: thin dark shins
    _leg(c, j, "f", s, P["robe_s"], P["void"], P["leather"], P["leather_s"])
    c.part(robe & c.capsule((hem_b, hem_y - 30), (hem_f, hem_y - 30), 30, 30), P["robe"], P["robe_s"], outline=False)
    # a ragged shoulder mantle in lighter trim, the hunch made obvious
    mp = [add(neck, mul(fwd, 3.0)), add(j.shoulder_f, add(mul(fwd, 3.0), mul(up, -2.0))),
          add(j.shoulder_f, add(mul(fwd, 1.5), mul(up, -6.0))), add(j.shoulder_f, add(mul(back, 0.5), mul(up, -4.5))),
          add(j.shoulder_f, add(mul(back, 2.5), mul(up, -7.0))), add(j.shoulder_f, add(mul(back, 4.5), mul(up, -4.0))),
          add(j.shoulder_f, add(mul(back, 6.5), mul(up, -6.5))), add(j.shoulder_f, add(mul(back, 7.5), mul(up, -1.0))),
          add(neck, add(mul(back, 5.0), mul(up, 1.0)))]
    c.part(c.poly(mp), P["robe_t"], P["robe"], shade_px=1)
    # hood: a cowl around the head with a pointed peak falling backwards
    head = j.head
    tilt = j.head_tilt
    hood_pts = [
        add(head, add(mul(fwd, 5.2), mul(up, 2.5))),
        add(head, add(mul(fwd, 4.6), mul(up, -4.0))),
        add(head, add(mul(fwd, 1.0), mul(up, -6.5))),
        add(neck, mul(back, 4.0)),
        add(head, add(mul(back, 6.0), mul(up, 1.0))),
        add(head, add(mul(back, 7.5 + 1.2 * math.sin(phase + 1)), mul(up, 6.5))),
        add(head, add(mul(back, 1.5), mul(up, 6.5))),
        add(head, add(mul(fwd, 3.5), mul(up, 5.0))),
    ]
    hood = c.poly(hood_pts)
    c.part(hood, P["robe"], P["robe_s"], shade_px=2, light=P["robe_t"])
    # the face hole: void with two glinting eyes
    face = c.ellipse(add(head, add(mul(fwd, 2.6), mul(up, -0.2))), 2.6, 3.6, tilt)
    c.paint(face, P["void"])
    for k in (0.0, 1.0):
        e = c.dot(add(head, add(mul(fwd, 2.4 + k * 1.6), mul(up, 0.6 - k * 0.0))))
        c.paint(e, P["teal"], P["teal"])
    # front arm, with a teal-glowing hand
    _arm(c, j, "f", s, None, None, P["pale"], P["pale_s"], sleeve=P["robe"], sleeve_s=P["robe_s"],
         glow=P["teal"])


def necro_frames():
    s = NECRO_SPEC
    W, H = 72, 76
    base = base_pose(lean=0.12, ua_f=0.25, fa_f=0.7, ua_b=-0.05, fa_b=0.35)
    out = {}

    def render(pose, phase=0.0, cast=0.0, rot_ang=0.0, ground=True, dy=0):
        c = scratch(160, (80, 120), rot_ang, (0, 0))
        j = solve(s, pose)
        draw_necromancer(c, j, s, phase, cast)
        return crop(c, W, H, ground=ground, dy=dy, centre=rot_ang != 0.0)

    # idle: breathing, cloak stirring, fingers flexing
    out["idle"] = [render(dict(base, crouch=k * 0.6, fa_f=0.7 + k * 0.08), phase=k * 1.5)
                   for k in (0, 1, 2, 1)]
    out["walk"] = [render(walk_pose(base, i * math.pi / 3, stride=0.38, swing=0.3), phase=i * math.pi / 3)
                   for i in range(6)]
    out["run"] = [render(walk_pose(dict(base, lean=0.28), i * math.pi / 3, stride=0.6, swing=0.6, knee=1.3),
                         phase=i * math.pi / 2) for i in range(6)]
    # cast: both hands thrown forward and up, palms out
    cast_poses = [
        dict(base, ua_f=1.0, fa_f=1.5, ua_b=0.6, fa_b=1.2, lean=0.05),
        dict(base, ua_f=1.9, fa_f=2.0, ua_b=1.5, fa_b=1.8, lean=-0.08, crouch=0.5),
        dict(base, ua_f=1.75, fa_f=1.75, ua_b=1.4, fa_b=1.5, lean=-0.06),
        dict(base, ua_f=1.85, fa_f=1.95, ua_b=1.45, fa_b=1.7, lean=-0.07, crouch=0.5),
    ]
    out["cast"] = [render(p, phase=i, cast=1.0) for i, p in enumerate(cast_poses)]
    out["work"] = out["cast"]
    jump = dict(base, th_f=0.9, sh_f=-0.2, th_b=0.3, sh_b=-0.5, ua_f=1.2, fa_f=1.6, ua_b=0.9, fa_b=1.3, lean=0.1)
    fall = dict(base, th_f=0.4, sh_f=0.1, th_b=-0.2, sh_b=-0.4, ua_f=2.3, fa_f=2.5, ua_b=2.0, fa_b=2.4, lean=0.0)
    out["jump"] = [render(jump, phase=2.0)]
    out["fall"] = [render(fall, phase=3.0), render(dict(fall, ua_f=2.5, ua_b=2.2), phase=4.0)]
    out["hurt"] = [tint(render(dict(base, lean=-0.25, head=-0.3, ua_f=0.8, fa_f=1.4), phase=1.0), (1.3, 0.85, 0.85)),
                   render(dict(base, lean=-0.18, ua_f=0.6, fa_f=1.1), phase=1.5)]
    out["die"] = _die_frames(lambda pose, ra: render(pose, phase=0.5, rot_ang=ra), base)
    return out


def _die_frames(render, base):
    """Knees buckle, then a topple backwards onto the ground."""
    knees = dict(base, th_f=0.9, sh_f=-0.6, th_b=0.7, sh_b=-0.8, lean=0.35, ua_f=0.2, fa_f=0.1, ua_b=0.0, fa_b=0.0, head=0.4)
    return [
        render(dict(base, lean=-0.2, head=-0.3, ua_f=0.9, fa_f=1.4), 0.0),
        render(knees, 0.0),
        render(dict(knees, th_f=1.2, th_b=1.0), -0.7),
        render(dict(knees, th_f=0.3, sh_f=0.2, th_b=0.2, sh_b=0.1, lean=0.0, ua_f=2.6, fa_f=2.8), -1.45),
    ]


# ---------------------------------------------------------------- shared head drawing

def _head(c, j, r, skin, skin_s, hair=None, hair_style="short", eye=None, eye_glow=None, jaw_open=0.0,
          nose=True, brow=True):
    up, fwd, back = j.up, j.fwd, j.back
    h = j.head
    m = c.ellipse(h, r * 0.95, r * 1.12, j.head_tilt)
    # long chin / jaw jutting down-forward (Darkest Dungeon faces are long)
    jaw = c.capsule(add(h, mul(up, -1.0)), add(h, add(mul(fwd, r * 0.55), mul(up, -r * 1.25 - jaw_open))), r * 0.6, r * 0.45)
    c.part(m | jaw, skin, skin_s, shade_px=1)
    if nose:
        c.paint(c.dot(add(h, add(mul(fwd, r + 0.4), mul(up, -0.5)))), skin)
        c.paint(c.dot(add(h, add(mul(fwd, r + 0.4), mul(up, -1.5)))), skin_s)
    if jaw_open > 0:
        mouth = c.capsule(add(h, add(mul(fwd, r * 0.5), mul(up, -r * 0.75))), add(h, add(mul(fwd, r * 0.9), mul(up, -r * 0.85 - jaw_open * 0.6))), 0.8, 0.8)
        c.paint(mouth, P["void"])
    else:
        c.paint(c.line(add(h, add(mul(fwd, r * 0.35), mul(up, -r * 0.85))), add(h, add(mul(fwd, r * 0.85), mul(up, -r * 0.8)))), skin_s)
    e = c.dot(add(h, add(mul(fwd, r * 0.5), mul(up, 0.6))))
    c.paint(e, eye or P["void"], eye_glow)
    if brow:
        c.paint(c.line(add(h, add(mul(fwd, r * 0.15), mul(up, 1.8))), add(h, add(mul(fwd, r * 0.8), mul(up, 1.4)))), P["ink"])
    if hair is not None:
        if hair_style == "short":
            hm = c.ellipse(add(h, add(mul(up, r * 0.45), mul(back, r * 0.25))), r * 0.95, r * 0.7, j.head_tilt)
            hm |= c.ellipse(add(h, add(mul(up, 0.0), mul(back, r * 0.65))), r * 0.45, r * 0.85, j.head_tilt)
            c.part(hm & ~c.ellipse(add(h, add(mul(fwd, r * 0.6), mul(up, -0.5))), r * 0.55, r * 0.9), hair[0], hair[1], shade_px=1, outline=False)
        elif hair_style == "bald_tufts":
            for k in (-0.6, 0.1):
                c.paint(c.line(add(h, add(mul(back, r * 0.7 - k), mul(up, r * 0.6))), add(h, add(mul(back, r * 1.1 - k), mul(up, r * 1.1)))), hair[0])


def _stitches(c, a, b, n, color=None):
    """A stitched seam from a to b with little cross-ticks."""
    color = color or P["stitch"]
    c.paint(c.line(a, b), color)
    d = sub(b, a)
    L = max(1e-6, math.hypot(*d))
    nrm = (-d[1] / L, d[0] / L)
    for i in range(n):
        p = lerp(a, b, (i + 0.5) / n)
        c.paint(c.line(add(p, mul(nrm, 1.2)), add(p, mul(nrm, -1.2))), color)


# ---------------------------------------------------------------- the ghoul (and rotling)

GHOUL_SPEC = Spec(thigh=11, shin=12, foot=4, torso=17, upper=12, fore=13, head_r=4.5, hunch=4.5, head_fwd=4.5,
                  chest_r=5.5, hip_r=4.0, limb_r=2.0, limb_r2=1.6, leg_r=2.2, leg_r2=1.7, shoulder_back=2.0)

GHOUL_SKIN = {
    "ghoul": dict(skin=P["ghoul"], skin_s=P["ghoul_s"], arm=P["ghoul_b"], arm_s=P["ghoul_bs"],
                  rag=P["rag"], rag_s=P["rag_s"], eye=P["teal"]),
    "rotling": dict(skin=P["rot"], skin_s=P["rot_s"], arm=P["skin"], arm_s=P["skin_s"],
                    rag=P["red_cloth"], rag_s=P["red_cloth_s"], eye=P["teal"]),
}


def draw_ghoul(c, j, s, kind="ghoul", jaw=1.0, weapon=False):
    k = GHOUL_SKIN[kind]
    up, back, fwd = j.up, j.back, j.fwd
    # back limbs
    _leg(c, j, "b", s, k["skin_s"], P["ink"], k["skin_s"], P["ink"])
    _arm(c, j, "b", s, k["skin_s"], P["ink"], k["skin_s"], P["ink"], hand_r=2.2)
    # torso: a hunched sack, ribs and stitches
    torso = c.chain([j.hip, j.chest, j.neck], [s.hip_r, s.chest_r, s.neck_r + 1])
    c.part(torso, k["skin"], k["skin_s"], shade_px=2)
    for i in range(3):
        a = lerp(j.chest, j.hip, 0.1 + i * 0.22)
        c.paint(c.line(add(a, mul(fwd, 1.0)), add(a, add(mul(fwd, 3.8), mul(up, -0.8)))), k["skin_s"])
    _stitches(c, add(j.neck, mul(fwd, 1.0)), add(j.hip, mul(fwd, 2.0)), 5)
    # loincloth rag
    rag = c.poly([add(j.hip, add(mul(back, 4.5), mul(up, 2.0))), add(j.hip, add(mul(fwd, 4.0), mul(up, 2.0))),
                  add(j.hip, add(mul(fwd, 3.0), mul(up, -5.0))), add(j.hip, add(mul(fwd, 0.5), mul(up, -3.5))),
                  add(j.hip, add(mul(back, 1.5), mul(up, -6.5))), add(j.hip, add(mul(back, 4.5), mul(up, -2.0)))])
    c.part(rag, k["rag"], k["rag_s"], shade_px=1)
    # front leg
    _leg(c, j, "f", s, k["skin"], k["skin_s"], k["skin"], k["skin_s"])
    # head: low, jutting, slack-jawed, glowing eye
    _head(c, j, s.head_r, k["skin"], k["skin_s"], hair=(P["hair_g"], P["ash"]), hair_style="bald_tufts",
          eye=k["eye"], eye_glow=k["eye"], jaw_open=jaw, brow=True)
    _stitches(c, add(j.head, add(mul(back, 3.5), mul(up, 3.0))), add(j.head, add(mul(fwd, 1.0), mul(up, 4.5))), 3)
    # front arm: the mismatched one, stitched on at the shoulder
    _arm(c, j, "f", s, k["arm"], k["arm_s"], k["arm"], k["arm_s"], hand_r=2.3)
    sh = j.shoulder_f
    _stitches(c, add(sh, add(mul(up, 2.0), mul(back, 1.5))), add(sh, add(mul(up, -1.5), mul(fwd, 2.5))), 3)
    if weapon:
        # a rusty cleaver in the front hand
        h = j.hand_f
        d = sub(j.hand_f, j.elbow_f)
        L = max(1e-6, math.hypot(*d))
        d = (d[0] / L, d[1] / L)
        handle = c.capsule(add(h, mul(d, -1.5)), add(h, mul(d, 3.0)), 0.9, 0.9)
        c.part(handle, P["wood"], P["wood_s"], shade_px=1)
        nrm = (d[1], -d[0])
        tip = add(h, mul(d, 3.0))
        blade = c.poly([tip, add(tip, mul(d, 8.0)), add(add(tip, mul(d, 8.5)), mul(nrm, 4.0)), add(tip, mul(nrm, 3.5))])
        c.part(blade, P["iron"], P["rust"], shade_px=1)


def _ghoul_frames(kind, weapon):
    s = GHOUL_SPEC
    W, H = (92, 80) if weapon else (76, 72)
    base = base_pose(lean=0.55, ua_f=-0.05, fa_f=0.15, ua_b=-0.25, fa_b=-0.05, th_f=0.25, sh_f=-0.05,
                     th_b=-0.05, sh_b=-0.25)

    def render(pose, jaw=1.0, rot_ang=0.0):
        c = scratch(160, (80, 120), rot_ang)
        draw_ghoul(c, solve(s, pose), s, kind, jaw, weapon)
        return crop(c, W, H, centre=rot_ang != 0.0)

    out = {}
    out["idle"] = [render(dict(base, crouch=k * 0.7, head=k * 0.08, ua_f=-0.05 + k * 0.05), jaw=1.0 + k * 0.6)
                   for k in (0, 1, 2, 1)]
    # the lurch: a dragging, uneven shamble
    walk = []
    for i in range(6):
        ph = i * math.pi / 3
        p = walk_pose(base, ph, stride=0.42, swing=0.12, knee=1.1)
        p["lean"] = base["lean"] + 0.08 * math.sin(ph * 2)
        p["head"] = 0.15 * math.sin(ph)
        walk.append(render(p, jaw=1.0 + (i % 3) * 0.4))
    out["walk"] = walk
    out["run"] = [render(dict(walk_pose(dict(base, lean=0.75), i * math.pi / 3, stride=0.62, swing=0.5, knee=1.4),
                              ua_f=1.2 + 0.3 * math.sin(i), fa_f=1.4, ua_b=1.0, fa_b=1.2), jaw=2.0) for i in range(6)]
    # work: digging / clawing, two-handed hacking downward
    work_poses = [dict(base, ua_f=2.3, fa_f=2.6, ua_b=2.0, fa_b=2.4, lean=0.2),
                  dict(base, ua_f=1.3, fa_f=1.0, ua_b=1.1, fa_b=0.8, lean=0.6),
                  dict(base, ua_f=0.55, fa_f=0.2, ua_b=0.4, fa_b=0.1, lean=0.85, crouch=2.0),
                  dict(base, ua_f=0.7, fa_f=0.5, ua_b=0.5, fa_b=0.3, lean=0.8, crouch=1.5)]
    out["work"] = [render(p, jaw=1.5) for p in work_poses]
    out["cast"] = out["work"]
    # carry: arms up over the shoulders, load is drawn by whoever carries
    carry_base = dict(base, ua_f=2.4, fa_f=3.0, ua_b=2.2, fa_b=2.9, lean=0.45)
    out["carry"] = [render(walk_pose(carry_base, i * math.pi / 2, stride=0.38, swing=0.0, knee=1.0), jaw=1.5)
                    for i in range(4)]
    out["jump"] = [render(dict(base, th_f=1.0, sh_f=-0.3, th_b=0.4, sh_b=-0.6, ua_f=1.4, fa_f=1.6, ua_b=1.2, fa_b=1.4), jaw=2.0)]
    out["fall"] = [render(dict(base, th_f=0.4, sh_f=0.2, th_b=-0.1, sh_b=-0.3, ua_f=2.6, fa_f=2.8, ua_b=2.4, fa_b=2.6, lean=0.3), jaw=2.5),
                   render(dict(base, th_f=0.5, sh_f=0.3, th_b=-0.2, sh_b=-0.4, ua_f=2.8, fa_f=3.0, ua_b=2.5, fa_b=2.7, lean=0.3), jaw=2.0)]
    out["hurt"] = [tint(render(dict(base, lean=0.1, head=-0.4, ua_f=0.6, fa_f=1.0), jaw=2.5), (1.3, 0.85, 0.85)),
                   render(dict(base, lean=0.3, ua_f=0.3, fa_f=0.6), jaw=2.0)]
    knees = dict(base, th_f=1.2, sh_f=-0.5, th_b=1.0, sh_b=-0.7, lean=0.9, ua_f=0.1, fa_f=0.0, ua_b=-0.1, fa_b=0.0)
    out["die"] = [render(dict(base, lean=0.2, head=-0.5, ua_f=1.2, fa_f=1.8), jaw=3.0, rot_ang=0.0),
                  render(knees, jaw=2.0),
                  render(dict(knees, lean=1.1), jaw=1.5, rot_ang=0.6),
                  render(dict(base, th_f=0.2, sh_f=0.1, th_b=0.0, sh_b=0.0, lean=0.1, ua_f=0.3, fa_f=0.3, ua_b=-0.3, fa_b=0.0), jaw=1.0, rot_ang=1.5)]
    return out


def ghoul_frames():
    return _ghoul_frames("ghoul", False)


def rotling_frames():
    return _ghoul_frames("rotling", True)


# ---------------------------------------------------------------- farmers and villagers (adults only)

PEASANT_SPEC = Spec(thigh=14, shin=14, foot=5, torso=18, upper=12, fore=12, head_r=4.5, hunch=1.5, head_fwd=1.5,
                    chest_r=4.6, hip_r=4.2, limb_r=1.9, limb_r2=1.6, leg_r=2.3, leg_r2=1.8)

PEASANTS = {
    "farmer": dict(shirt=P["linen"], shirt_s=P["linen_s"], vest=P["brown"], vest_s=P["brown_s"],
                   trousers=P["green_cloth"], trousers_s=P["green_cloth_s"], boots=P["leather"], boots_s=P["leather_s"],
                   skin=P["skin"], skin_s=P["skin_s"], hair=(P["hair"], P["leather_s"]), hat="straw", tool="pitchfork",
                   skirt=False),
    "villager": dict(shirt=P["red_cloth"], shirt_s=P["red_cloth_s"], vest=P["linen"], vest_s=P["linen_s"],
                     trousers=P["rag"], trousers_s=P["rag_s"], boots=P["leather_s"], boots_s=P["void"],
                     skin=P["skin"], skin_s=P["skin_s"], hair=(P["hair_g"], P["ash"]), hat="kerchief", tool=None,
                     skirt=True),
}


def _pitchfork(c, j, d_ang=None):
    h, e = j.hand_f, j.elbow_f
    d = sub(h, e)
    L = max(1e-6, math.hypot(*d))
    d = (d[0] / L, d[1] / L)
    # the haft runs through the hand, mostly upright, tines up and forward
    up = j.up
    axis = (0.25 + d[0] * 0.2, -1.0)
    L2 = math.hypot(*axis)
    axis = (axis[0] / L2, axis[1] / L2)
    a = add(h, mul(axis, -16))
    b = add(h, mul(axis, 22))
    c.part(c.capsule(a, b, 0.8, 0.8), P["wood"], P["wood_s"], shade_px=1)
    nrm = (-axis[1], axis[0])
    cross_a, cross_b = add(b, mul(nrm, -3.0)), add(b, mul(nrm, 3.0))
    m = c.capsule(cross_a, cross_b, 0.6, 0.6)
    for k in (-3.0, 0.0, 3.0):
        base = add(b, mul(nrm, k))
        m |= c.capsule(base, add(base, mul(axis, 6.0 if k == 0 else 5.5)), 0.5, 0.4)
    c.part(m, P["iron"], P["iron_s"], shade_px=1)


def draw_peasant(c, j, s, kind, phase=0.0):
    k = PEASANTS[kind]
    up, back, fwd = j.up, j.back, j.fwd
    _leg(c, j, "b", s, k["trousers_s"], P["ink"], k["boots_s"], P["ink"])
    _arm(c, j, "b", s, k["shirt_s"], P["ink"], k["skin_s"], P["ink"], sleeve=k["shirt_s"], sleeve_s=P["ink"])
    if not k["skirt"]:
        _leg(c, j, "f", s, k["trousers"], k["trousers_s"], k["boots"], k["boots_s"])
    torso = c.chain([add(j.hip, (0, -1)), j.chest, j.neck], [s.hip_r, s.chest_r, s.neck_r + 1.2])
    c.part(torso, k["shirt"], k["shirt_s"], shade_px=2)
    if k["skirt"]:
        hem_y = max(j.ankle_f[1], j.ankle_b[1]) - 3
        hf = max(j.knee_f[0], j.ankle_f[0], j.hip[0] + 6) + 2
        hb = min(j.knee_b[0], j.ankle_b[0], j.hip[0] - 7) - 2
        skirt = c.poly([add(j.hip, add(mul(back, 4.5), mul(up, 3))), add(j.hip, add(mul(fwd, 4.5), mul(up, 3))),
                        (hf, hem_y), (lerp((hb, 0), (hf, 0), 0.5)[0], hem_y + 1), (hb, hem_y)])
        c.part(skirt, k["trousers"], k["trousers_s"], shade_px=2)
        # apron
        ap = c.poly([add(j.hip, add(mul(fwd, 1.0), mul(up, 4))), add(j.hip, add(mul(fwd, 4.8), mul(up, 4))),
                     (hf - 2, hem_y - 5), (hf - 6, hem_y - 4)])
        c.part(ap, k["vest"], k["vest_s"], shade_px=1)
        for side in ("f", "b"):
            an, to = (j.ankle_f, j.toe_f) if side == "f" else (j.ankle_b, j.toe_b)
            c.part(c.capsule(add(an, (0, -2)), an, 1.6, 1.8) | c.capsule(an, to, 1.6, 1.2), k["boots"], k["boots_s"], shade_px=1)
    else:
        # waistcoat over the shirt, rope belt
        vest = c.chain([add(j.hip, mul(up, 2)), j.chest, lerp(j.chest, j.neck, 0.8)], [s.hip_r + 0.2, s.chest_r + 0.3, s.neck_r + 1.0])
        vest &= ~c.capsule(add(j.chest, mul(fwd, 3.5)), add(j.neck, mul(fwd, 2.5)), 1.8, 1.4)
        c.part(vest, k["vest"], k["vest_s"], shade_px=2)
        c.paint(c.capsule(add(j.hip, add(mul(back, 4), mul(up, 2.5))), add(j.hip, add(mul(fwd, 4), mul(up, 2.5))), 0.7, 0.7), P["leather_s"])
    _head(c, j, s.head_r, k["skin"], k["skin_s"], hair=k["hair"], eye=P["void"])
    h = j.head
    if k["hat"] == "straw":
        brim = c.ellipse(add(h, mul(up, s.head_r * 0.75)), s.head_r * 2.0, 1.4, j.head_tilt)
        crown = c.ellipse(add(h, mul(up, s.head_r * 1.15)), s.head_r * 0.95, s.head_r * 0.7, j.head_tilt)
        c.part(brim | crown, P["straw"], P["straw_s"], shade_px=1)
        c.paint(c.line(add(h, add(mul(back, s.head_r * 0.9), mul(up, s.head_r * 0.95))), add(h, add(mul(fwd, s.head_r * 0.9), mul(up, s.head_r * 0.95)))), P["red_cloth_s"])
    elif k["hat"] == "kerchief":
        kc = c.ellipse(add(h, add(mul(up, s.head_r * 0.45), mul(back, 0.6))), s.head_r * 1.05, s.head_r * 0.85, j.head_tilt)
        kc &= ~c.ellipse(add(h, add(mul(fwd, s.head_r * 0.75), mul(up, -0.8))), s.head_r * 0.6, s.head_r * 1.0)
        tail = c.poly([add(h, add(mul(back, s.head_r * 0.6), mul(up, 0))), add(h, add(mul(back, s.head_r * 1.7), mul(up, -2.5 - math.sin(phase)))),
                       add(h, add(mul(back, s.head_r * 0.9), mul(up, -2.0)))])
        c.part(kc | tail, P["linen"], P["linen_s"], shade_px=1)
    _arm(c, j, "f", s, k["shirt"], k["shirt_s"], k["skin"], k["skin_s"], sleeve=k["shirt"], sleeve_s=k["shirt_s"])
    if k["tool"] == "pitchfork":
        _pitchfork(c, j)


def _peasant_frames(kind):
    s = PEASANT_SPEC
    W, H = 88, 88
    tool = PEASANTS[kind]["tool"]
    base = base_pose(lean=0.1, ua_f=0.45 if tool else 0.1, fa_f=1.3 if tool else 0.3, ua_b=-0.1, fa_b=0.1)

    def render(pose, phase=0.0, rot_ang=0.0):
        c = scratch(170, (85, 125), rot_ang)
        draw_peasant(c, solve(s, pose), s, kind, phase)
        return crop(c, W, H, centre=rot_ang != 0.0)

    out = {}
    out["idle"] = [render(dict(base, crouch=k * 0.5, head=-0.05 * k), phase=k) for k in (0, 1, 1, 0)]
    out["walk"] = [render(dict(walk_pose(base, i * math.pi / 3, stride=0.45, swing=0.0 if tool else 0.35),
                               **({"ua_f": base["ua_f"], "fa_f": base["fa_f"]} if tool else {})), phase=i)
                   for i in range(6)]
    run_base = dict(base, lean=0.3)
    out["run"] = [render(walk_pose(run_base, i * math.pi / 3, stride=0.7, swing=0.7, knee=1.4), phase=i) for i in range(6)]
    if tool:
        # jab with the pitchfork
        out["work"] = [render(dict(base, ua_f=0.9, fa_f=1.7, lean=0.0)), render(dict(base, ua_f=1.3, fa_f=1.6, lean=0.25, th_f=0.4, sh_f=0.1)),
                       render(dict(base, ua_f=1.5, fa_f=1.55, lean=0.35, th_f=0.5, sh_f=0.1)), render(dict(base, ua_f=1.1, fa_f=1.6, lean=0.15))]
    else:
        # wringing hands, praying, shaking a fist: one cheap gesture loop
        out["work"] = [render(dict(base, ua_f=0.9, fa_f=2.2, ua_b=0.7, fa_b=2.0)), render(dict(base, ua_f=1.0, fa_f=2.4, ua_b=0.8, fa_b=2.2)),
                       render(dict(base, ua_f=0.9, fa_f=2.2, ua_b=0.7, fa_b=2.0, head=0.1)), render(dict(base, ua_f=2.6, fa_f=2.9, ua_b=0.7, fa_b=2.0))]
    out["cast"] = out["work"]
    out["carry"] = [render(walk_pose(dict(base, ua_f=1.1, fa_f=2.1, ua_b=0.9, fa_b=2.0), i * math.pi / 2, stride=0.35, swing=0.0)) for i in range(4)]
    out["jump"] = [render(dict(base, th_f=0.9, sh_f=-0.2, th_b=0.3, sh_b=-0.5, ua_b=1.0, fa_b=1.3))]
    out["fall"] = [render(dict(base, th_f=0.4, sh_f=0.2, th_b=-0.2, sh_b=-0.4, ua_b=2.4, fa_b=2.6, lean=0.0))]
    out["hurt"] = [tint(render(dict(base, lean=-0.25, head=-0.35, ua_b=0.9, fa_b=1.5)), (1.3, 0.85, 0.85)),
                   render(dict(base, lean=-0.15, head=-0.2))]
    knees = dict(base, th_f=1.1, sh_f=-0.5, th_b=0.9, sh_b=-0.7, lean=0.4, ua_f=0.3, fa_f=0.3, ua_b=0.0, fa_b=0.1, head=0.4)
    out["die"] = [render(dict(base, lean=-0.25, head=-0.4, ua_f=1.0, fa_f=1.6, ua_b=1.2, fa_b=1.7)),
                  render(knees),
                  render(dict(knees, lean=0.6), rot_ang=0.7),
                  render(dict(base, th_f=0.15, sh_f=0.1, th_b=0.0, sh_b=0.0, lean=0.0, ua_f=0.5, fa_f=0.6, ua_b=-0.4, fa_b=-0.2), rot_ang=1.5)]
    return out


def farmer_frames():
    return _peasant_frames("farmer")


def villager_frames():
    return _peasant_frames("villager")
