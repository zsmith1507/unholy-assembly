# Working in this repo

Unholy Assembly is a 2D necromancer factory sim on a falling-sand world. Zach is building it with Claude. The game itself is the Godot 4.7 project in `game/`, with the pixel simulation in C++ under `native/`; the browser prototypes in `prototypes/` are where the simulation was first worked out. Read `docs/design-doc.md` for the design and `docs/ARCHITECTURE.md` for how the Godot code is split into departments.

## Workflow (Zach's choice)

- **This repo is the only source of truth.** Edit the prototypes here; don't publish them as separate Claude-hosted pages.
- **Commit and push straight to `main`** after each change Zach asks for, one commit per change, with a message saying what changed and why. GitHub Pages serves `main`, so the live links update a minute or two after a push:
  - https://zsmith1507.github.io/unholy-assembly/prototypes/proving-ground.html
  - https://zsmith1507.github.io/unholy-assembly/prototypes/charnel-pit.html
- **Before every push of Godot work, run `tools/godot-check.sh`** (import, every department's tests, a ten-second boot); it must pass. Godot 4.7.1 must be on the PATH as `godot`.
- **Before every push that touches the prototypes, run `node tools/smoke-test.js`.** It boots each prototype headlessly and runs ten seconds of game time; it must pass. For changes to behaviour or tuning, also measure the specific thing that changed with a quick headless script, and report the before/after numbers to Zach in plain terms.

## The prototypes

- Each prototype is one self-contained HTML file: inline CSS and JS, with Google Fonts the only external dependency. Keep them that way, so they open by double-click and on Pages.
- `prototypes/proving-ground.html` is the most current engine: Dig and Harvest spells, ragdolls, collapsing terrain, powder inertia, shading, and wind/force fields. `prototypes/charnel-pit.html` is the earlier physics sandbox and lacks those engine additions.
- Tuning numbers live in named config objects (`DIG`, `HARV`, `REND`, `CHUNK`, `WEIGHT`, `RAG`, `FOE`, `COLLAPSE`, `FRIC`, `MANA_*`, the per-material `DEF[...]` entries). When Zach asks to change how something feels, change the number in its config block rather than scattering literals, and tell him which knob it was.
- Mana regeneration is set very fast for demo purposes (`MANA_REGEN`, `MANA_DELAY`).

## The Godot game

- Open `game/` in Godot 4.7. The C++ sim library for each platform is built by GitHub Actions and committed to `game/bin/` whenever `native/` changes, so Zach never needs a compiler.
- Work is split into departments, one folder each (`game/sim`, `necro`, `flesh`, `lair`, `world`, `threats`, `eyegor`, `art`), with the lead owning `game/main`, `game/core`, `game/autoload` and `game/tests`. `docs/ARCHITECTURE.md` lists who owns what and the APIs between them.
- Zach steers each department from the Assembly Floor console (a Claude artifact): https://claude.ai/artifact/X1FN4jTDTyiPda9SC8kKq9. Its messages live in the artifact's database; read them with the ArtifactData tool (`messages` collection, filter on `area`).
- Tuning numbers live in named `const` dictionaries at the top of each script, same rule as the prototypes.
