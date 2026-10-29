"""Eyegor, Director of Undying Resources: a floating bloodshot eye with black feathered wings, holding a
clipboard and a quill. eyegor_portrait (96 x 96, for the advisor panel) and eyegor (34 x 34, in-world).
Drawn at a scale S; body space origin is the bottom-centre of the frame."""
import math

import numpy as np

from pix import P, add, crop, hexc, scratch

LID = hexc("4a3a44")
LID_S = hexc("2e242c")
VEIN = hexc("b0443c")
IRIS = {"chipper": P["teal_m"], "proud": hexc("d0a850"), "concerned": hexc("d8843a"), "memo": hexc("b0302a")}


def _wing(c, side, S, cy, flap):
    """Black wing: tiers of long feathers fanning out from the eye's side. flap -1 down .. 1 up."""
    root = (side * 15 * S, cy - 2 * S)
    m = np.zeros((c.h, c.w), bool)
    feathers = []
    for i in range(6):
        ang = (-0.15 + i * 0.22 + flap * 0.35) # 0 = straight out, + up
        L = (30 - abs(i - 2) * 3.0) * S
        tip = add(root, (side * math.cos(ang) * L, -math.sin(ang) * L))
        f = c.capsule(root, tip, 4.5 * S, 1.4 * S)
        feathers.append((root, tip))
        m |= f
    cov = c.ellipse(add(root, (side * 7 * S, -4 * S - flap * 4 * S)), 10 * S, 7 * S)
    c.part(m, P["feather"], P["feather_s"], shade_px=max(1, int(S * 2)))
    c.part(cov, P["feather_l"], P["feather"], shade_px=1)
    if S > 0.6:
        for r, t in feathers:
            mid = add(r, ((t[0] - r[0]) * 0.35, (t[1] - r[1]) * 0.35))
            c.paint(c.line(mid, add(t, (-side * 1.5 * S, 0))), P["feather_s"])
        for k in range(3):
            p = add(root, (side * (4 + k * 4) * S, -(2 + k * 2 + flap * 3) * S))
            c.paint(c.line(p, add(p, (side * 3 * S, 2 * S))), P["feather"])


def draw(c, S=1.0, flap=0.0, bob=0.0, look=(0.0, 0.0), mood="chipper", lid=0.0, smile=0.0, write=-1, glow=False):
    cy = -50 * S + bob * S
    R = 19 * S
    eye_c = (0, cy)
    _wing(c, -1, S, cy, flap)
    _wing(c, 1, S, cy, flap)
    # the eye
    ball = c.ellipse(eye_c, R, R)
    c.part(ball, P["eye_white"], P["bone_s"], shade_px=max(1, int(2 * S)))
    if S > 0.6:
        rng = np.random.RandomState(7)
        for k in range(9):
            a = rng.uniform(0, 2 * math.pi)
            p0 = add(eye_c, (math.cos(a) * R * 0.98, math.sin(a) * R * 0.98))
            p1 = add(eye_c, (math.cos(a + 0.2) * R * 0.62, math.sin(a + 0.2) * R * 0.62))
            p2 = add(p1, (math.cos(a + 1.1) * 3 * S, math.sin(a + 1.1) * 3 * S))
            c.paint((c.line(p0, p1) | c.line(p1, p2)) & ball, VEIN)
    ic = add(eye_c, (look[0] * R * 0.45, look[1] * R * 0.45))
    iris = c.ellipse(ic, 8 * S, 8.5 * S) & ball
    col = IRIS.get(mood, P["teal_m"])
    c.paint(iris, col, col if glow else None)
    c.paint(c.ellipse(ic, 8 * S, 8.5 * S) & ~c.ellipse(ic, 6.6 * S, 7.1 * S) & ball, P["teal_d"] if mood == "chipper" else P["rust"])
    c.paint(c.ellipse(ic, 3.8 * S, 4.4 * S) & ball, P["void"])
    c.paint(c.ellipse(add(ic, (-3 * S, -3.5 * S)), max(0.8, 1.6 * S), max(0.8, 1.6 * S)) & ball, (255, 255, 255, 255))
    # lids: the upper one drops when concerned; the lower one rises when he's pleased with himself
    if lid > 0:
        top = c.ellipse(add(eye_c, (0, -R * (1.0 + 0.9 * (1 - lid)) + R * 0.2)), R * 1.25, R * 1.0) & ball
        c.paint(top, LID)
        edge = top & ~np.roll(top, -1, axis=0)
        c.paint(edge, P["ink"])
    if smile > 0:
        bot = c.ellipse(add(eye_c, (0, R * (1.0 + 0.9 * (1 - smile)) - R * 0.25)), R * 1.25, R * 1.0) & ball
        c.paint(bot, LID)
        edge = bot & ~np.roll(bot, 1, axis=0)
        c.paint(edge, P["ink"])
    # the clipboard, held up in front, below the eye
    bw, bh = 15 * S, 20 * S
    by = cy + R + 1 * S
    board = c.poly([(-bw, by), (bw, by - 1 * S), (bw, by + bh), (-bw, by + bh + 1 * S)])
    c.part(board, P["wood"], P["wood_s"], shade_px=1)
    paper = c.poly([(-bw + 2 * S, by + 2 * S), (bw - 2 * S, by + 1 * S), (bw - 2 * S, by + bh - 1.5 * S), (-bw + 2 * S, by + bh - 0.5 * S)])
    c.paint(paper, P["paper"])
    c.paint(paper & ~np.roll(paper, -1, axis=1), P["paper_s"])
    if S > 0.6:
        for k in range(5):
            y = by + (5 + k * 3) * S
            w = (0.85 if k % 2 else 0.6) * (bw - 5 * S)
            c.paint(c.line((-bw + 4 * S, y), (-bw + 4 * S + w * 2 * 0.85, y - 0.2 * S)), P["paper_s"] if k else P["ink"])
        c.paint(c.line((-bw + 4 * S, by + 20 * S), (-bw + 6 * S, by + 18 * S)) | c.line((-bw + 6 * S, by + 18 * S), (-bw + 9 * S, by + 21 * S)), P["blood_d"])
    clip = c.poly([(-4 * S, by - 2 * S), (4 * S, by - 2 * S), (4 * S, by + 2.5 * S), (-4 * S, by + 2.5 * S)])
    c.part(clip, P["iron"], P["iron_s"], shade_px=1)
    # wingtip "hands" curling round the board's sides
    for side in (-1, 1):
        hand = c.ellipse((side * (bw + 0.5 * S), by + bh * 0.45), 3.2 * S, 5.5 * S, side * 0.3)
        c.part(hand, P["feather"], P["feather_s"], shade_px=1)
    # the quill: nib on the paper, vane sweeping up to the right
    nib = (2 * S + (write % 4) * 3 * S if write >= 0 else 4 * S, by + (12 + (write % 2) * 2) * S if write >= 0 else by + 12 * S)
    tip = add(nib, (17 * S, -24 * S))
    shaft = c.line(nib, tip)
    vane = c.capsule(add(nib, (6 * S, -8 * S)), tip, 1.0 * S, 3.6 * S) & ~c.capsule(nib, add(nib, (5 * S, -7 * S)), 2.5 * S, 2.5 * S)
    c.part(vane, P["blood"], P["blood_d"], shade_px=1)
    c.paint(shaft, P["bone"] if S > 0.6 else P["bone_s"])
    c.paint(c.dot(nib), P["ink"])
    hold = c.ellipse(add(nib, (6.5 * S, -6.5 * S)), 3.0 * S, 2.6 * S)
    c.part(hold, P["feather"], P["feather_s"], shade_px=1)


def _frame(W, H, S, **kw):
    c = scratch(int(max(W, H) * 2), (int(max(W, H)), int(max(W, H) * 1.5)))
    draw(c, S, **kw)
    return crop(c, W, H, ground=False)


def portrait_frames():
    W = H = 96
    S = 0.98
    flaps = (0.0, 0.5, 1.0, 0.4)
    bobs = (0, -1, -2, -1)
    out = {}
    out["idle"] = [_frame(W, H, S, flap=f, bob=b, look=(0.15, 0.05)) for f, b in zip(flaps, bobs)]
    looks = ((0.3, 0.1), (-0.15, 0.25), (0.25, 0.3), (0.0, 0.05))
    out["talk"] = [_frame(W, H, S, flap=f, bob=b, look=l, write=i) for i, (f, b, l) in enumerate(zip(flaps, bobs, looks))]
    out["concerned"] = [_frame(W, H, S, flap=f * 0.4, bob=b, look=(0.1, 0.3), mood="concerned", lid=0.55) for f, b in zip(flaps, bobs)]
    out["proud"] = [_frame(W, H, S, flap=f, bob=b, look=(0.0, -0.2), mood="proud", smile=0.5) for f, b in zip(flaps, bobs)]
    out["memo"] = [_frame(W, H, S, flap=f * 0.3, bob=b, look=(0.1, 0.4), mood="memo", lid=0.3, write=i) for i, (f, b) in enumerate(zip(flaps, bobs))]
    return out


def world_frames():
    W = H = 36
    S = 0.37
    flaps = (0.0, 0.6, 1.0, 0.3)
    bobs = (0, -2, -3, -1)
    out = {}
    out["idle"] = [_frame(W, H, S, flap=f, bob=b * 2, look=(0.3, 0.1), glow=True) for f, b in zip(flaps, bobs)]
    out["walk"] = [_frame(W, H, S, flap=f * 1.4 - 0.2, bob=b * 2, look=(0.5, 0.0), glow=True) for f, b in zip(flaps, bobs)]
    out["talk"] = [_frame(W, H, S, flap=f, bob=b * 2, look=(0.2, 0.2), write=i, glow=True) for i, (f, b) in enumerate(zip(flaps, bobs))]
    return out


SPRITES = {
    "eyegor_portrait": (portrait_frames, {"idle": 6.0, "talk": 8.0, "concerned": 5.0, "proud": 6.0, "memo": 6.0}),
    "eyegor": (world_frames, {"idle": 7.0, "walk": 10.0, "talk": 8.0}),
}
