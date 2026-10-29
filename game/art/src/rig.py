"""A lanky humanoid rig: joints from a pose, so walk/cast/die frames are poses, not hand-drawn copies.

Body space: origin on the ground between the feet, +x forward (characters face right), +y down.
Angles: 0 points straight down, positive swings forward (towards +x), pi points straight up.
"""
import math

from pix import add, lerp, mul, polar, sub


class Spec:
    """Proportions in pixels. Lanky Darkest Dungeon defaults; characters override."""

    def __init__(self, **kw):
        self.thigh = 15
        self.shin = 15
        self.foot = 5
        self.torso = 20
        self.upper = 13
        self.fore = 13
        self.head_r = 5
        self.neck = 2
        self.hip_r = 4.0
        self.chest_r = 5.0
        self.neck_r = 2.0
        self.limb_r = 2.0      # upper limb radius
        self.limb_r2 = 1.6     # lower limb radius
        self.leg_r = 2.4
        self.leg_r2 = 1.8
        self.hunch = 0.0       # spine bulge backwards, px
        self.head_fwd = 0.0    # head jut forward, px
        self.shoulder_back = 1.5
        self.__dict__.update(kw)


def base_pose(**kw):
    p = dict(lean=0.0, th_f=0.08, sh_f=0.02, th_b=-0.08, sh_b=-0.12,
             ua_f=0.15, fa_f=0.35, ua_b=-0.1, fa_b=0.1, head=0.0, bob=0.0, dx=0.0, crouch=0.0)
    p.update(kw)
    return p


def walk_pose(base, phase, stride=0.5, swing=0.35, knee=0.9, bob=1.0):
    p = dict(base)
    s, c = math.sin(phase), math.cos(phase)
    p["th_f"] = base["th_f"] + stride * s
    p["sh_f"] = p["th_f"] - knee * max(0.0, c) - 0.05
    p["th_b"] = base["th_b"] - stride * s
    p["sh_b"] = p["th_b"] - knee * max(0.0, -c) - 0.05
    p["ua_f"] = base["ua_f"] - swing * s
    p["fa_f"] = p["ua_f"] + (base["fa_f"] - base["ua_f"]) + 0.15 * max(0, -s)
    p["ua_b"] = base["ua_b"] + swing * s
    p["fa_b"] = p["ua_b"] + (base["fa_b"] - base["ua_b"]) + 0.15 * max(0, s)
    return p


class Joints:
    pass


def solve(spec, pose):
    """Joint positions for a pose. The hip height is set so the lower foot rests on y = 0."""
    j = Joints()
    lean = pose["lean"]
    up = (math.sin(lean), -math.cos(lean))
    back = (-math.cos(lean), -math.sin(lean))
    fwd = mul(back, -1)

    def leg(th, sh):
        knee = polar(spec.thigh, th)
        ankle = add(knee, polar(spec.shin, sh))
        return knee, ankle

    kf, af = leg(pose["th_f"], pose["sh_f"])
    kb, ab = leg(pose["th_b"], pose["sh_b"])
    drop = max(af[1], ab[1])  # how far the lower ankle hangs below the hip
    # Spread legs lower the hip by themselves (drop shrinks), so walks bob without help.
    hip = (pose.get("dx", 0.0), -drop - 1.5 + pose.get("crouch", 0.0))
    j.hip = hip
    j.knee_f, j.ankle_f = add(hip, kf), add(hip, af)
    j.knee_b, j.ankle_b = add(hip, kb), add(hip, ab)
    j.toe_f = add(j.ankle_f, (spec.foot, 0.5))
    j.toe_b = add(j.ankle_b, (spec.foot, 0.5))
    j.up, j.back, j.fwd = up, back, fwd
    j.chest = add(add(hip, mul(up, spec.torso * 0.55)), mul(back, spec.hunch))
    j.neck = add(add(hip, mul(up, spec.torso)), mul(fwd, spec.head_fwd * 0.4))
    j.shoulder_f = add(lerp(j.chest, j.neck, 0.75), mul(fwd, 0.5))
    j.shoulder_b = add(j.shoulder_f, mul(back, spec.shoulder_back))
    j.elbow_f = add(j.shoulder_f, polar(spec.upper, pose["ua_f"]))
    j.hand_f = add(j.elbow_f, polar(spec.fore, pose["fa_f"]))
    j.elbow_b = add(j.shoulder_b, polar(spec.upper, pose["ua_b"]))
    j.hand_b = add(j.elbow_b, polar(spec.fore, pose["fa_b"]))
    head_up = add(j.neck, mul(up, spec.neck + spec.head_r * 0.85))
    j.head = add(head_up, mul(fwd, spec.head_fwd))
    j.head_tilt = pose.get("head", 0.0) + lean * 0.3
    return j
