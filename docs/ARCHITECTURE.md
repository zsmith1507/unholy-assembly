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
| `necro_spawn` | Vector2 | Where the necromancer starts, feet position: the middle of the forest between the two towns |
| `surface_y_px` | float | Typical surface height (pixels), for quick checks |
| `surface_at` | Callable(x_px) -> float | Surface height at an x, from the generated heightmap |
| `graveyard` | Rect2 | The town cemetery, in pixels; coffins are buried under it |
| `graves` | Array[Vector2] | Each buried coffin's centre, pixels |
| `towns` | Array[Dictionary] | `{name, rect: Rect2, side: -1 or 1, fields: Rect2, homes: Array[Dictionary]}`; a home is `{id, rect, residents: int, alive: int, door: Vector2 (floor level, px), town: String}` |
| `critter_zones` | Array[Rect2] | Forest areas where critters spawn |
| `patrol_routes` | Array[PackedVector2Array] | Surface paths patrols walk (one per town, out to just past the forest middle, plus one across the graveyard) |
| `world_seed` | int | The seed the world was generated from (World's default is 666) |
| `settlements` | Node | The settlements node (same as the `settlements` group hook) |
| `battlefield` | Rect2 | The old battlefield, pixels |
| `catacomb` | Rect2 | The deep catacomb, pixels |
| `lair_builder` | Node | Added by Lair's installer: the builder (same as the `lair_builder` group hook) |
| `flesh_spawner` | Node | Added by Bodies and Souls' installer: the spawner (same as the `flesh_spawner` group hook) |

## Autoloads (global services)

| Name | Script | Owner | Use it for |
| --- | --- | --- | --- |
| `Events` | `autoload/events.gd` | Lead | The signal bus. Departments talk through signals here. |
| `GameState` | `autoload/game_state.gd` | Lead | Souls in the heart, fragments, mana (in souls' worth), Suspicion, Hunger, the heart, the clock, unlocks, stats. Change values only through its methods. |
| `Sim` | `autoload/sim.gd` | Pixel Physics | `Sim.world` (the `SandWorld`), unit conversion, `solid_at`, `dig_px`, `spill_px`, `raycast_px`. |
| `Jobs` | `lair/jobs.gd` | Lair | The ghoul job board. Spells post dig and haul work here. |
| `Narrative` | `eyegor/narrative.gd` | Eyegor | `say(text, mood)`, `line(key)`, `describe_item(kind)`. All player-facing text goes through here. |
| `Threats` | `threats/threat_director.gd` | Suspicion | Converts noise, sightings and missing bodies into Suspicion; spawns patrols. |

## Hooks between departments

These are the only places departments call each other directly. Everything else goes through `Events`, `GameState` and `Jobs`. Implement your side exactly as written; if a hook needs to change, ask on `#floor`.

| Hook | Provided by | Used by | Shape |
| --- | --- | --- | --- |
| Lair builder | Lair: a node in group `lair_builder`, added by `lair/install.gd` | Necromancer's build spell | `can_place(kind: StringName, at: Vector2) -> bool`, `place(kind, at) -> Node2D` (null if refused), `cost(kind) -> Dictionary` (e.g. `{"mana": 0.2}`), `kinds() -> Array[StringName]` (`&"heart"`, `&"grinder"`, `&"stitching_table"`, `&"altar"`, `&"spike_trap"`); optional `footprint(kind) -> Vector2` (pixels) and `why_not(kind, at) -> String` (`""` if placeable, else `not_dug`, `no_floor`, `overlap`, `out_of_range`, `one_heart`). `at` is the middle of the footprint's bottom edge. Liquid in a footprint doesn't block it, and bumps up to `BUILD.floor_give_px` high are levelled when it is built |
| Interactables | Lair (heart, machines, altar) and anyone else | Necromancer's interact key | Node in group `interactable` with `interact(by: Node2D) -> void` and `interact_hint() -> String`; the necromancer uses the nearest one within 24 px |
| Pullables | Bodies and Souls (corpses, parts, critters, living humans), Lair (items) | Necromancer's Harvest spell | Node in group `pullable` with `apply_pull(force: Vector2) -> void` (pixels per tick², applied for one tick). Living humans resist by their `fear` and `brace`. |
| Siphonable | Bodies and Souls (corpses, parts) | Necromancer's Siphon spell | Node in group `siphonable` with `siphon(amount: float) -> float` returning mana gained in souls' worth; the thing turns to ash as it empties. Blood on the ground is siphoned straight from the sim. |
| Flesh spawner | Bodies and Souls: node in group `flesh_spawner` | Threats (patrols), Lair (testing) | `spawn_human(kind: StringName, at: Vector2) -> Actor` (`&"farmer"`, `&"villager"`), `spawn_critter(kind, at) -> Actor` (`&"rabbit"`, `&"crow"`, `&"deer"`), `spawn_soul_orb(at: Vector2, amount: float, source: String) -> Node2D` |
| Human orders | Bodies and Souls (human actors) | Threats | `set_route(points: PackedVector2Array)`, `investigate(at: Vector2)`, `set_mode(mode: StringName)` (`&"home"`, `&"work"`, `&"patrol"`, `&"flee"`, `&"attack"`), `fear: float` 0–1, signal `noticed(what: Node2D)` |
| Spell list | Necromancer (node in group `necro`) | HUD | `get_spells() -> Array` of `{id, name, cost_text, color}`, `get_selected_spell() -> StringName`; emits `Events.spell_selected` |
| Settlements | World: node in group `settlements` | Threats, Bodies and Souls | `homes() -> Array[Dictionary]`, `resident_died(home_id: int)`, `home_at(pos: Vector2) -> Dictionary`; homes decay when empty and slowly refill. Signals `home_emptied(home)` (the last resident died; the home starts to decay) and `resident_arrived(home)` (a newcomer moved in; Bodies and Souls puts a new human there) |
| Lighting | Art: node in group `lighting` | Lair, Necromancer, World | `add_light(node: Node2D, color: Color, radius_px: float, energy: float) -> PointLight2D` so everyone's lights share one look. Art scales every light by one shared table (`ArtLighting.LIGHT`) and attaches the glow shader from `art/install.gd` |

Souls rule (from the design doc): a human's soul is collected only if the necromancer is within `SOULS.witness_radius` of the death, or the death is inside the heart's range, where the orb drifts home by itself. Bodies and Souls implements this in its soul orb.

### Round 5 hooks (from Zach's playtest notes, docs/playtest-notes-1.md)

| Hook | Provided by | Used by | Shape |
| --- | --- | --- | --- |
| Satchel (inventory) | Lead: `GameState` | Necromancer (Harvest adds), Lair (table and altar take), Eyegor (shows it) | `GameState.add_item(kind, amount) -> float`, `item_count(kind)`, `has_items(cost: Dictionary)`, `take_items(cost) -> bool` (all or nothing), `inventory` dict, `INVENTORY_CAP`; signal `Events.inventory_changed(kind, amount, total)`. Kinds `&"flesh"`, `&"bones"`, `&"blood"`. Souls never go in the satchel; they go to the heart |
| Components | Bodies and Souls (corpses, parts) | Necromancer's Harvest | Node in group `harvestable` with `components() -> Dictionary` (what it yields now, e.g. `{&"flesh": 2, &"bones": 1, &"blood": 1}`; blood only while fresh) and `consume() -> Dictionary` (yields that, frees or empties the node, and spills a little gore). Harvest pulls a body apart (existing pull and sever), and each piece that reaches the necromancer's hand is `consume()`d into the satchel instead of dropping at his feet. A fresh body's soul follows the souls rule as before |
| Build menu | Eyegor: menu node in group `build_menu` (opened by the `build_menu` action) | Necromancer | Menu lists `lair_builder.kinds()` with `lair_builder.describe(kind)` and calls `necro.begin_placement(kind)`; the Necromancer shows the ghost, places on `cast`, cancels on `cast_alt` or Esc, and emits `Events.build_placement_started/ended`. Build is no longer a spell on the spell bar |
| Builder description | Lair: `lair_builder.describe(kind) -> Dictionary` | Eyegor's build menu | `{name: String, cost: Dictionary, footprint: Vector2, unlocked: bool, blurb: String}`. The first heart of a run costs nothing (`cost(&"heart")` returns `{}` until one has been built) |
| Talents and skills | Necromancer: node in group `talents` | Eyegor's talent screen (opened by the `talents` action), every department that reads an upgrade | `trees() -> Array` of `{id, name, kind: "talent"|"skill", nodes: [{id, name, desc, cost, max_rank, rank, requires: Array[StringName], pos: Vector2i}]}`, `points() -> int`, `can_learn(id) -> bool`, `learn(id) -> bool`, `rank(id) -> int`; signals `Events.talent_learned`, `Events.skill_points_changed`. Talents are passive upgrades (dig speed and cost, mana, harvest reach); skills unlock abilities (spirit vision, corpse sense). Other departments read upgrades with `get_tree().get_first_node_in_group("talents").rank(&"id")` |
| Melee | Necromancer (`attack` action, a starting knife) | Bodies and Souls, Threats | Hits call `Actor.take_damage(amount, necro)`; costs no mana; makes a little noise |
| Shroud (fog of war) | Pixel Physics: node in group `shroud` | Necromancer's skills, World, Art | Underground earth is hidden except near the necromancer and in places he has uncovered. `reveal_radius_cells: int`, `corpse_sense_radius_px: float` (0 = off; when on, buried bodies within range show as red spirit gas), `is_revealed(pos: Vector2) -> bool`, `reveal_area(rect_px: Rect2)`. It draws above items and actors (z 15), so buried bodies stay hidden until uncovered |
| Buildings and doors | World: each house has an outside facade and a separate interior | Necromancer (enter with `move_up` or `interact` at a door), Bodies and Souls (residents live inside), Threats (witnesses inside) | Door nodes in group `doors` with `interact(by)` that move `by` to the paired door (`Events.entered_building` / `left_building`). Each `info.towns[*].homes[*]` gains `interior: Rect2` (pixels) and `door_inside: Vector2`. The camera follows the player into the interior |
| Buried bodies wake | Bodies and Souls | Necromancer, World | A grave corpse becomes a normal visible corpse as soon as its coffin is broken open or the ground around it is dug out, without needing Harvest |
| Coffin wood | Pixel Physics: material `SandWorld.M_COFFIN` (planks with a wood grain) | World (builds coffins from it) | Static, diggable like wood, burns like wood |

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

Added by Pixel Physics:

```
take_crush_events() -> Array of {rect: Rect2i, force: float, landed: bool, cells: int, speed: float}
    ground that broke loose and is falling or just landed since the last call (a falling chunk reports each
    tick it moves, and once more when it lands; force = speed x cells x CRUSH.force_per)
get_heat(x, y) -> float · add_heat(cx, cy, r, amount)      heat field (about 7 lights wood, 3 tallow)
get_stain(x, y) -> int                                      which liquid stained this cell (0 = clean)
is_burning(x, y) -> bool                                    a cell on fire right now
falling_chunk_count() -> int · particle_count() -> int      for debug overlays and tests
```

Pixel Physics may add methods; it does not change these. Ground only breaks loose when `dig()`, `explode()` or fire cuts it free; nothing caves in by itself.

## Rules every department follows

- **Tuning lives in a named `const` Dictionary at the top of the script** (`const DIG := {...}`, `const GHOUL := {...}`), never as scattered literals, so Zach can say "make digging slower" and we change one number.
- **Player-facing text goes through `Narrative`.** Use `Narrative.say()` for Eyegor lines and `Narrative.line()` for labels; the Eyegor department writes the words.
- **Noise and sightings go through `Events`.** Emit `Events.noise_made(at, loudness, source)` about once a second while your thing is loud (not every tick); Threats decides what it costs, muffled by the earth above. Loudness is on a 0–1 scale: about 0.08 a ghoul at work, 0.15–0.25 a stitching table or altar, 0.7 the grinder, up to 1.0 the Dig spell in stone; only an explosion goes past 1. `source` is a short word for the overlay (`"grinder"`, `"ghoul"`).
- **Content boundary from the design doc:** no children on screen, ever. Every human who appears is an adult. Gore stays pixel-chunky.
- **Tests:** put headless tests in `game/<dept>/tests/test_*.gd` (see `game/tests/runner.gd`). Run everything with `tools/godot-check.sh`. A test file that doesn't compile, makes no checks, logs an engine or script error, or runs past its time limit (120 s of game time; set `const TEST_TIMEOUT_S` to change it) fails, and the run moves on.
- **The hidden start, played:** `game/tests/test_hidden_start.gd` plays the opening on the real generated world with every department's real nodes (`game/tests/hidden_start.gd` holds the steps). Where it has to help (mana topped up, a thing carried by hand) it prints an `ASSIST` line; fewer assists means a more playable start. `game/tests/drive_hidden_start.gd` plays the same steps in `shot.tscn` and saves a screenshot after each (pass `--no-title` so Eyegor's title screen doesn't wait for a click): `xvfb-run -a godot --path game --rendering-driver opengl3 --fixed-fps 60 res://tests/shot.tscn -- --scene=res://main/main.tscn --frames=80000 --drive=res://tests/drive_hidden_start.gd --no-title`.
- **Screenshots** (to see what you built): `xvfb-run -a godot --path game --rendering-driver opengl3 --fixed-fps 60 res://tests/shot.tscn -- --scene=res://main/main.tscn --frames=180 --out=/tmp/shot.png`.

## Building the C++ sim

```
cd native
scons target=template_debug debug_symbols=no      # Linux library for local testing
```

On every push that touches `native/`, GitHub Actions builds Windows, Linux and macOS libraries and commits them to `game/bin/` (`.github/workflows/build-sim.yml`). Zach never needs a compiler: pull, open `game/` in Godot 4.7, press Play.
