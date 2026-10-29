"""Contact sheet of every sprite (first frame of each animation, glow composited) at 2x:
python3 contact_sheet.py /tmp/unholy-shots/art_sheet.png"""
import os
import sys

from PIL import Image, ImageDraw

import build_all

HERE = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(HERE, "..", "sprites")
BG = (22, 18, 26)
SCALE = 2


def first_frames(name):
    anims = build_all.SPRITES[name][0]()
    out = []
    for a, fs in anims.items():
        for f in (fs[:2] if len(fs) > 1 and a in ("idle", "work", "talk") else fs[:1]):
            col = Image.fromarray(f.col, "RGBA")
            glow = Image.fromarray(f.glow, "RGBA")
            im = Image.new("RGBA", col.size, BG + (255,))
            im.alpha_composite(col)
            g = Image.new("RGBA", col.size, (0, 0, 0, 0))
            g.alpha_composite(glow)
            im = Image.blend(im, Image.alpha_composite(im, g), 0.5)
            out.append((a, im))
    return out


def main(path):
    rows = []
    for name in build_all.SPRITES:
        fr = first_frames(name)
        w = sum(im.width * SCALE + 6 for _, im in fr)
        h = max(im.height for _, im in fr) * SCALE + 14
        row = Image.new("RGB", (max(w, 120), h), BG)
        d = ImageDraw.Draw(row)
        x = 0
        for a, im in fr:
            row.paste(im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST).convert("RGB"), (x, h - im.height * SCALE))
            d.text((x + 1, 0), a, fill=(120, 110, 120))
            x += im.width * SCALE + 6
        rows.append((name, row))
    # parts
    parts = Image.new("RGB", (4 * 4 * 26 * SCALE, 30 * SCALE + 14), BG)
    x = 0
    for look in ("villager", "farmer", "ghoul", "rotling"):
        for p in ("head", "torso", "arm", "leg"):
            im = Image.open(os.path.join(SPR, "%s_%s.png" % (look, p))).convert("RGBA")
            bg = Image.new("RGBA", im.size, BG + (255,))
            bg.alpha_composite(im)
            parts.paste(bg.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST).convert("RGB"), (x, parts.height - im.height * SCALE))
            x += im.width * SCALE + 4
        x += 10
    rows.append(("body_parts", parts))
    # two columns
    col_w = 760
    cols = [[], []]
    hs = [0, 0]
    for name, row in rows:
        k = 0 if hs[0] <= hs[1] else 1
        cols[k].append((name, row))
        hs[k] += row.height + 16
    sheet = Image.new("RGB", (col_w * 2 + 30, max(hs) + 30), BG)
    d = ImageDraw.Draw(sheet)
    d.text((10, 6), "Unholy Assembly - Art and Lighting sprite sheet (2x). Regenerate: game/art/src/build_all.py", fill=(170, 160, 150))
    for k in (0, 1):
        y = 24
        for name, row in cols[k]:
            d.text((10 + k * (col_w + 10), y), name, fill=(127, 232, 216))
            sheet.paste(row.crop((0, 0, min(row.width, col_w - 80), row.height)), (90 + k * (col_w + 10), y))
            y += row.height + 16
    sheet.save(path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/unholy-shots/art_sheet.png")
