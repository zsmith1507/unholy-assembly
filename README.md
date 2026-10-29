# Unholy Assembly

A 2D side-scrolling factory sim with a gothic, gallows-humour streak. You play a necromancer harvesting a battlefield for body parts to build zombies for an ever-growing war on the forces of "good". The diggable world is a Noita-style falling-sand simulation; the game itself will be built in Godot.

## Playing the game

1. Install [Godot 4.7](https://godotengine.org/download).
2. In Godot's project manager, choose **Import**, pick `game/project.godot` from this repository, and open it.
3. Press **Play** (F5, or the triangle at the top right).

The pixel simulation is a C++ extension. GitHub Actions builds it for Windows, Linux and macOS and commits the libraries to `game/bin/`, so there is nothing to compile: pull the latest `main` and press Play.

### Controls

| Keyboard and mouse | Gamepad (Steam Deck) | Action |
|---|---|---|
| A / D (or arrow keys) | Left stick, d-pad | Walk |
| Space or W | A | Jump; hold in the air to levitate for a moment; swim up |
| S | Left stick down | Dive, or drop faster |
| Mouse | Right stick | Aim |
| Left mouse button (hold) | Right trigger | Cast the chosen spell |
| Right mouse button | Left trigger | The spell's second use: Build picks the next building, Dig Here and Stockpile cancel a drag or pick the resource |
| E | X | Use the thing you stand next to: refill mana at the heart, touch the altar to raise, visit a striking ghoul |
| 1 to 6, Tab, mouse wheel | Bumpers | Choose a spell |

The spells, in order:

1. **Dig**: a beam that wears the ground away, softest first. Loud.
2. **Harvest**: a cone of grave-wind that draws bodies, parts and loose things to your hand and drops them at your feet. Bore down to a coffin with Dig, then draw the corpse up.
3. **Siphon**: drink mana from corpses, parts and pools of blood. They crumble to ash.
4. **Build**: place the necrotic heart first, then the corpse grinder, stitching table, reanimation altar and spike trap inside its range. The ghost turns green where it fits.
5. **Dig Here**: drag a rectangle over ground; your ghouls dig it out.
6. **Stockpile**: drag a rectangle in a dug-out hollow; ghouls keep it stocked with gibs, bones or corpses.

**The opening (the hidden start):** dig down into the forest floor and hollow out a hall, Build the heart in it, rob a coffin in the graveyard, feed the corpse to the grinder, carry the gibs and bones to the stitching table and the stitched body to the altar, then touch the altar (E) to raise your first ghoul. Mark ground with Dig Here and the ghoul digs it. Critters in the woods give soul fragments; five make a soul. The heart's souls refill your mana.

Pause, Eyegor's clipboard (F1) and the HUD arrive with the Eyegor and HUD department.

The game is being built department by department (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)); the design is in [docs/design-doc.md](docs/design-doc.md).

## Prototypes

Browser prototypes used to work out the simulation before porting it to Godot. Each is a single self-contained HTML file: open it in any modern browser. Fonts load from Google Fonts; everything else is inline.

Play them online (GitHub Pages, from `main`):
- [Proving Ground](https://zsmith1507.github.io/unholy-assembly/prototypes/proving-ground.html)
- [Charnel Pit](https://zsmith1507.github.io/unholy-assembly/prototypes/charnel-pit.html)

`node tools/smoke-test.js` boots each prototype headlessly and runs ten seconds of game time to catch errors.

### `prototypes/charnel-pit.html`: the physics sandbox

Paint materials into a crypt pit and watch them interact.

- **Liquids** (blood, holy water, ichor, tallow) fall with momentum, plunge into pools, splash, and blend where they meet.
- **Fire** spreads through a heat field. Wood burns slowly and sheds embers. Tallow pools burn from the surface down; airborne fat flashes.
- **Stains** are driven into surfaces on impact, deeper for faster hits and softer materials. Blood dries brown over time.

### `prototypes/proving-ground.html`: the spell range

Play the necromancer in a graveyard full of buried coffins, liquid pockets, a crypt, and patrolling crusaders.

| Input | Action |
|---|---|
| A / D | Walk |
| W / Space | Jump, or swim up |
| S | Dive, or drop faster |
| 1 / 2 | Choose Dig or Harvest |
| Left mouse | Channel the chosen spell |
| Right mouse | Paint the test material |
| C | Summon a crusader at the cursor |
| R | New graveyard |
| P | Pause |

- **Dig**: a channelled beam that wears down terrain by hardness. Undercut ground breaks off and falls as one chunk, shatters on landing, and crushes anything beneath it.
- **Harvest**: a cone of grave-wind pulling straight into the necromancer's hand. Bodies come apart by part weight: arms first, then head, legs, and torso. Pieces break into chunks, and smaller chunks fly faster; single pixels race in alongside the blood. Living crusaders brace against the pull. Each has a `fear` value, unused for now, that will later let them break free and run.
- **Bodies** are six-segment rigs (head, torso, two arms, two legs). In death they become ragdolls with severable joints and pumping wounds.

## Simulation notes for the Godot port

- The world is a grid of cells updated bottom-to-top each tick. Liquids and powders share one swap-based update.
- Powders have a moving/resting state with per-material friction, which gives each material its own angle of repose.
- Heat is a separate field that diffuses and rises. Materials ignite above a per-material threshold, and only where they touch air.
- Detached terrain is found by flood-filling from cut points. Anything not connected to bedrock or the map edge falls as a rigid chunk.
- Each prototype keeps its tuning numbers in named blocks near the top of the relevant section (`DIG`, `HARV`, `REND`, `CHUNK`, `WEIGHT`, `RAG`, `FOE`, `COLLAPSE`, `FRIC`, and so on).
- Ideas worth adopting from other falling-sand projects: pressure-based liquids for pipes (FallingSandSurvival, 2D Liquid Simulator), sleeping inactive chunks (sand-slide), and data-driven reaction tables.
