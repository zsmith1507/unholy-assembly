# Unholy Assembly: how the Godot game is put together

The game lives in `game/` (open that folder in Godot 4.7). The falling-sand simulation is C++ in `native/`, compiled into `game/bin/`. The design is in [design-doc.md](design-doc.md); this file is the technical contract between departments.

**Current goal: the playable hidden start.** Dig a lair, place the necrotic heart, rob the graveyard by magic, kill critters for soul fragments, run corpse grinder → stitching table → reanimation altar, raise ghouls who haul and dig, while farmer patrols wander the surface and Suspicion rises. Eyegor narrates.

## Departments and who owns what

Each department edits only its own folder. To change something another department owns, ask on the Assembly Floor console (or in that department's channel) and the owner or the lead makes the change.

| Department | Folder | Console channel | Owns |
| --- | --- | --- | --- |
| Lead (Claude) | `game/main/`, `game/core/`, `game/autoload/`, `game/tests/`, `docs/`, `tools/` | `#floor` | Main scene, shared base classes, autoloads, the contract in this file |
| Pixel Physics | `native/`, `game/sim/` | `#sim` | SandWorld (C++), its rendering, the `Sim` autoload's helpers |
| The Necromancer | `game/necro/` | `#necro` | Player movement, spells as tools, mana use, aiming |
| Bodies and Souls | `game/flesh/` | `#flesh` | Humans, critters, ragdolls and dismemberment, corpses and parts, soul orbs |
| Lair and Factory | `game/lair/` | `#lair` | The heart, machines, stockpiles, ghouls, the `Jobs` autoload |
| World and Towns | `game/world/` | `#world` | World generation, graveyard, towns and homes, day and night, background |
| Suspicion and Patrols | `game/threats/` | `#threats` | The two meters, farmer patrols, the `Threats` autoload |
| Eyegor and HUD | `game/eyegor/` | `#eyegor` | HUD, Eyegor, memos, milestones, title screen, all player-facing text, the `Narrative` autoload |
| Art and Lighting | `game/art/` | `#art` | Sprites (`ArtLib`), palette, lighting, darkness, glow, parallax backgrounds |

## Units and scale

- **Positions are pixels.** The viewport is 640×360, scaled up by whole numbers (1280×720, 1920×1080, Steam Deck 1280×800).
- **The sim works in cells.** One cell = `Sim.CELL` = 2×2 pixels. `Sim.to_cell(px)`, `Sim.to_pixel(cell)`, `Sim.cell_center(cell)` convert.
- **Time is ticks.** Physics runs at 60 ticks a second. Velocities in `GridBody` are pixels per tick.
- **Characters are about 64 px tall** (32 cells): necromancer 20×64, ghoul 18×52, farmer 18×60. Feet are at the node's origin.
- **Default world:** 1536×768 cells (3072×1536 px). Surface around 40% down; the lair goes below it.

## How a run is assembled

`game/main/main.gd` creates the sand world, builds the layers, then runs each department's installer in this order:

1. `res://world/install.gd`
2. `res://art/install.gd`
3. `res://lair/install.gd`
4. `res://flesh/install.gd`
5. `res://necro/install.gd`
6. `res://threats/install.gd`
7. `res://eyegor/install.gd`

An installer is a script that `extends RefCounted` with `func install(main: Main, info: Dictionary) -> Variant`. It adds nodes to main's layers and may return a Dictionary that is merged into `info` for the installers after it. A missing installer is skipped, so the game boots at every stage.

**Layers on `main`** (back to front): `background` (z −100), `terrain` (z 0, holds `sim_view`), `buildings` (4), `items` (5), `actors` (10), `fx` (20), `ui` (a CanvasLayer), plus `camera`. The necro installer sets `main.player`; the camera follows it.

### `info` keys (World writes them; everyone else reads them)

| Key | Type | Meaning |
| --- | --- | --- |
| `necro_spawn` | Vector2 | Where the necromancer starts, feet position |
| `surface_y_px` | float | Typical surface height (pixels), for quick checks |
| `surface_at` | Callable(x_px) -> float | Surface height at an x, from the generated heightmap |
| `graveyard` | Rect2 | The town cemetery, in pixels; coffins are buried under it |
| `graves` | Array[Vector2] | Each buried coffin's centre, pixels |
| `towns` | Array[Dictionary] | `{name, rect: Rect2, side: -1 or 1, homes: Array[Dictionary]}`; a home is `{id, rect, residents: int, alive: int}` |
| `critter_zones` | Array[Rect2] | Forest areas where critters spawn |
| `patrol_routes` | Array[PackedVector2Array] | Surface paths patrols walk |

## Autoloads (global services)

| Name | Script | Owner | Use it for |
| --- | --- | --- | --- |
| `Events` | `autoload/events.gd` | Lead | The signal bus. Departments talk through signals here. |
| `GameState` | `autoload/game_state.gd` | Lead | Souls in the heart, fragments, mana (in souls' worth), Suspicion, Hunger, the heart, the clock, unlocks, stats. Change values only through its methods. |
| `Sim` | `autoload/sim.gd` | Pixel Physics | `Sim.world` (the `SandWorld`), unit conversion, `solid_at`, `dig_px`, `spill_px`, `raycast_px`. |
| `Jobs` | `lair/jobs.gd` | Lair | The ghoul job board. Spells post dig and haul work here. |
| `Narrative` | `eyegor/narrative.gd` | Eyegor | `say(text, mood)`, `line(key)`, `describe_item(kind)`. All player-facing text goes through here. |
| `Threats` | `threats/threat_director.gd` | Suspicion | Converts noise, sightings and missing bodies into Suspicion; spawns patrols. |

## Shared base classes (`game/core/`)

- **`GridBody`** (`extends Node2D`): a box that moves through the sand world. Set `box_size`, `velocity`; call `move_tick()` each physics tick. Gives `on_floor`, `submerged`, `hit_wall`. Steps up small ledges, swims in liquid.
- **`Actor`** (`extends GridBody`): hp, faction (`NECRO`, `UNDEAD`, `HUMAN`, `CRITTER`, `DEMON`), `take_damage`, `die`. Joins groups `actors` and its faction group (`necro`, `minions`, `humans`, `critters`). Override `_on_death(killer)`.
- **`Item`** (`extends GridBody`): something carried and processed. `kind`: `corpse`, `part`, `gibs`, `bones`, `stitched_body`, `meat`, `metal`, `wood`, `stone`. `pick_up(by)`, `drop(at, vel)`, `reserved_by` for ghoul jobs. Joins `items` and `item_<kind>`.
- **`ArtLib`** (`game/art/art_lib.gd`, owned by Art): `ArtLib.make_sprite("ghoul")` gives an AnimatedSprite2D with feet at the origin. Placeholders until real art lands; no code changes when it does.

## The SandWorld API (C++, stable)

Cells, not pixels. Material constants are `SandWorld.M_DIRT`, `SandWorld.M_BLOOD`, etc. (IDs 0–21 match the browser prototypes).

```
setup(w, h, seed) · step() · get_width() · get_height() · get_tick()
get_mat(x, y) · set_mat(x, y, mat) · fill_rect(x, y, w, h, mat) · paint_circle(cx, cy, r, mat, only_empty)
is_solid(x, y) · is_liquid(x, y) · is_empty(x, y) · get_kind(x, y) · in_bounds(x, y)
raycast(from: Vector2i, to: Vector2i, stop_at_liquid) -> Vector2i (-1,-1 if clear)
count_rect(x, y, w, h) -> {mat: count} · surface_y(x, from_y)
dig(cx, cy, r, power) -> {mat: removed} · spill(x, y, mat, count, vx, vy) · ignite(x, y, r) · explode(cx, cy, r, force)
render_region(image, x0, y0) · render_glow(image, x0, y0) · get_cells() · set_cells(bytes)
wake_rect(x, y, w, h) · active_chunk_count()
SandWorld.mat_name(mat) · SandWorld.mat_kind(mat) · SandWorld.mat_hardness(mat)   (static)
```

Pixel Physics may add methods; it does not change these.

## Rules every department follows

- **Tuning lives in a named `const` Dictionary at the top of the script** (`const DIG := {...}`, `const GHOUL := {...}`), never as scattered literals, so Zach can say "make digging slower" and we change one number.
- **Player-facing text goes through `Narrative`.** Use `Narrative.say()` for Eyegor lines and `Narrative.line()` for labels; the Eyegor department writes the words.
- **Noise and sightings go through `Events`.** Emit `Events.noise_made(at, loudness, source)` when your thing is loud; Threats decides what it costs.
- **Content boundary from the design doc:** no children on screen, ever. Every human who appears is an adult. Gore stays pixel-chunky.
- **Tests:** put headless tests in `game/<dept>/tests/test_*.gd` (see `game/tests/runner.gd`). Run everything with `tools/godot-check.sh`.
- **Screenshots** (to see what you built): `xvfb-run -a godot --path game --rendering-driver opengl3 --fixed-fps 60 res://tests/shot.tscn -- --scene=res://main/main.tscn --frames=180 --out=/tmp/shot.png`.

## Building the C++ sim

```
cd native
scons target=template_debug debug_symbols=no      # Linux library for local testing
```

On every push that touches `native/`, GitHub Actions builds Windows, Linux and macOS libraries and commits them to `game/bin/` (`.github/workflows/build-sim.yml`). Zach never needs a compiler: pull, open `game/` in Godot 4.7, press Play.
