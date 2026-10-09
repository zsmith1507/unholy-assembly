# Unholy Assembly

A 2D side-scrolling factory sim with a gothic, gallows-humour streak. You play a necromancer harvesting a battlefield for body parts to build zombies for an ever-growing war on the forces of "good". The diggable world is a Noita-style falling-sand simulation; the game itself will be built in Godot.

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
