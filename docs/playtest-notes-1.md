# Playtest notes, round 1 (Zach, 2026-10-30)

Zach played the first merged build and dictated these notes. All fourteen are approved; every department works on its share at once. The live doc is https://claude.ai/artifact/48v3SqGWXYhuoafv3sCCXy.

| # | Note | Owner (others help) |
| --- | --- | --- |
| 1 | **Two-layer world.** Outside, houses are seen from the front (a facade). Standing at the front door and pressing up or E enters the house: a separate interior with its own walls. Leaving works the same way. | World (Necromancer: input; Bodies: residents inside; Art: facades and interiors) |
| 2 | **Bigger houses and a bigger world.** Houses fit about one person; most should be much bigger (not all). The whole world needs to be bigger; the forest start is too small to hide in. | World (Bodies: more residents; Pixel Physics: performance on a bigger world) |
| 3 | **Hunger only from depth, and a grace period.** Hunger should not build right away, only below a certain depth. Early on, a grace period before the meters climb. | Suspicion |
| 4 | **Slower digging that levels up.** Digging is too fast at first and burns mana too quickly. Start slower and cheaper, and improve it through upgrades. | Necromancer |
| 5 | **Talent tree and skill tree** for the necromancer. Dig speed and cost are a first candidate. | Necromancer (logic), Eyegor (screen) |
| 6 | **A proper build menu.** Build should not be a spell where right-click cycles through a flat list. | Eyegor (menu), Necromancer (placement), Lair (descriptions) |
| 7 | **The first necrotic heart is free.** | Lair |
| 8 | **A knife.** A way to hurt living things without mana; start him with a knife he can stab with. Other weapons later. | Necromancer |
| 9 | **Frame rate is very low** (seen in the browser). Likely about 490 draw calls per frame in the opening forest; browsers pay more per call. Physics is about 0.9 ms per step, so not the cause. Measure desktop vs browser, then cut draw calls. | Art (leads), everyone helps |
| 10 | **Parallax backgrounds as static images**: one or two pre-made layers sliding at different speeds, like Terraria and Noita. Static, not rebuilt every frame. | Art |
| 11 | **Coffins that look like wood**, with a coffin shape, not tan rectangles. | Pixel Physics (material), World (shape) |
| 12 | **Fog of war underground.** He shouldn't see through earth; buried coffins are visible from the side today. Shroud the underground; he sees only a little past himself. Later upgrades: spirit vision, and distant corpses glowing as red spirit gas through the earth. | Pixel Physics (shroud), Necromancer (skills) |
| 13 | **Bodies already inside coffins.** Breaking a coffin open shows nothing until Harvest is cast; the body should already be there. | Bodies and Souls |
| 14 | **An inventory and harvesting into parts.** Harvest takes a body apart into flesh, bones and blood (souls go to the heart) and draws them to him; he carries them and puts them straight onto the stitching table or the reanimation altar. Today Harvest drags whole corpses and burns all his mana. Ghouls, not the necromancer, haul to the corpse grinder. | Bodies (components), Necromancer (harvest and satchel), Lair (table and altar take from the satchel), Eyegor (satchel display) |

**Keep:** the lighting effects (Zach wants more of them) and the soul-capture range of the heart.

Earlier open items to fold in: the Quit buttons freeze the page in the browser (hide them on web); machines drop output into walls; Eyegor's "dig your first chamber" objective ignores digging done before the heart; machines never play their `work` animation; the altar needs a soul that the opening rarely provides.
