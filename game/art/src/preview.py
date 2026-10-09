"""Preview frames of one sprite at a scale over a dark background: python3 preview.py necro out.png"""
import sys
import numpy as np
from PIL import Image
import humans, beasts

def sheet(anims, scale=4, bg=(40, 34, 44)):
    rows = []
    fw = max(f.col.shape[1] for v in anims.values() for f in v)
    fh = max(f.col.shape[0] for v in anims.values() for f in v)
    n = max(len(v) for v in anims.values())
    img = np.zeros((fh * len(anims), fw * n, 4), np.uint8)
    img[...] = bg + (255,)
    for r, (a, fs) in enumerate(anims.items()):
        for k, f in enumerate(fs):
            h, w = f.col.shape[:2]
            reg = img[r*fh:r*fh+h, k*fw:k*fw+w]
            a_ = f.col[..., 3:4] / 255.0
            reg[..., :3] = (reg[..., :3] * (1 - a_) + f.col[..., :3] * a_).astype(np.uint8)
            g = f.glow[..., 3:4] / 255.0 * 0.5
            reg[..., :3] = np.clip(reg[..., :3] + f.glow[..., :3] * g, 0, 255).astype(np.uint8)
            reg[-1, :, :3] = (90, 60, 60)
    return Image.fromarray(img).resize((img.shape[1]*scale, img.shape[0]*scale), Image.NEAREST)

if __name__ == "__main__":
    mod = humans if hasattr(humans, sys.argv[1] + "_frames") else beasts
    fn = getattr(mod, sys.argv[1] + "_frames")
    sheet(fn()).save(sys.argv[2])
