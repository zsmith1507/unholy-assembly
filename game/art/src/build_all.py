"""Regenerate every sprite: cd game/art/src && python3 build_all.py  (deterministic output)."""
import humans
import beasts
import parts
from pix import write_sprite

SPRITES = {
    "necromancer": (humans.necro_frames, {"walk": 8.0, "run": 11.0, "cast": 8.0, "die": 6.0}),
    "ghoul": (humans.ghoul_frames, {"walk": 7.0}),
    "rotling": (humans.rotling_frames, {"walk": 7.0}),
    "farmer": (humans.farmer_frames, {"walk": 8.0}),
    "villager": (humans.villager_frames, {"walk": 8.0}),
    "rabbit": (beasts.rabbit_frames, {}),
    "crow": (beasts.crow_frames, {}),
    "deer": (beasts.deer_frames, {}),
    "pig": (beasts.pig_frames, {}),
    "chicken": (beasts.chicken_frames, {}),
}

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    if not only or "parts" in only:
        parts.build()
    for name, (fn, speeds) in SPRITES.items():
        if only and name not in only:
            continue
        anims = fn()
        write_sprite(name, anims, speeds=speeds)
        f = next(iter(anims.values()))[0]
        print("%-12s %dx%d  %s" % (name, f.col.shape[1], f.col.shape[0], ", ".join("%s:%d" % (a, len(v)) for a, v in anims.items())))
