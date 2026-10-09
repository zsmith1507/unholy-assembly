"""Severed body parts (head, torso, arm, leg) for ArtLib.body_parts, drawn with the same rig and palette."""
import numpy as np
import humans as H
from pix import P, add, mul, scratch, write_png
from rig import base_pose, solve


def _trim(c):
    a = c.col[..., 3] > 0
    ys, xs = np.where(a)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = c.col[y0:y1, x0:x1].copy()
    g = c.glow[y0:y1, x0:x1]
    m = g[..., 3] > 0
    out[m, :3] = np.maximum(out[m, :3], g[m, :3])
    return out


def _stump(c, p, r=1.6):
    m = c.ellipse(p, r, r)
    c.paint(m, P["blood"] if "blood" in P else (90, 20, 24, 255))


def parts_for(kind):
    if kind in ("ghoul", "rotling"):
        s, k = H.GHOUL_SPEC, H.GHOUL_SKIN[kind]
        skin, skin_s, arm, arm_s, shirt, shirt_s, trous, trous_s, boot, boot_s = (
            k["skin"], k["skin_s"], k["arm"], k["arm_s"], None, None, k["skin"], k["skin_s"], k["skin"], k["skin_s"])
        hair, eye, style = (P["hair_g"], P["ash"]), k["eye"], "bald_tufts"
    else:
        s, k = H.PEASANT_SPEC, H.PEASANTS[kind]
        skin, skin_s, arm, arm_s = k["skin"], k["skin_s"], k["skin"], k["skin_s"]
        shirt, shirt_s, trous, trous_s, boot, boot_s = k["shirt"], k["shirt_s"], k["trousers"], k["trousers_s"], k["boots"], k["boots_s"]
        hair, eye, style = k["hair"], P["void"], "short"
    j = solve(s, base_pose(lean=0.0, ua_f=0.0, fa_f=0.0, th_f=0.0, sh_f=0.0, head=0.0))
    out = {}
    c = scratch(120, (60, 90))
    H._head(c, j, s.head_r, skin, skin_s, hair=hair, hair_style=style, eye=eye, eye_glow=eye if kind in ("ghoul", "rotling") else None, jaw_open=1.0)
    _stump(c, add(j.neck, mul(j.up, 1.0)), 1.3)
    out["head"] = _trim(c)
    c = scratch(120, (60, 90))
    torso = c.chain([j.hip, j.chest, j.neck], [s.hip_r, s.chest_r, s.neck_r + 1])
    c.part(torso, shirt or skin, shirt_s or skin_s, shade_px=2)
    if shirt is None:
        H._stitches(c, add(j.neck, mul(j.fwd, 1.0)), add(j.hip, mul(j.fwd, 2.0)), 5)
    _stump(c, j.neck, 1.5)
    _stump(c, j.shoulder_f, 1.4)
    out["torso"] = _trim(c)
    c = scratch(120, (60, 90))
    H._arm(c, j, "f", s, arm, arm_s, arm, arm_s, sleeve=shirt, sleeve_s=shirt_s)
    _stump(c, j.shoulder_f, s.limb_r)
    out["arm"] = _trim(c)
    c = scratch(120, (60, 90))
    H._leg(c, j, "f", s, trous, trous_s, boot, boot_s)
    _stump(c, j.hip, s.leg_r)
    out["leg"] = _trim(c)
    return out


def build():
    for kind in ("farmer", "villager", "ghoul", "rotling"):
        for part, arr in parts_for(kind).items():
            write_png("%s_%s" % (kind, part), arr)
    # the necromancer and cattle share villager/farmer parts in-game; ghoul parts are the stitched spares


if __name__ == "__main__":
    build()
