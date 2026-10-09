# Working in this repo

Unholy Assembly is a 2D necromancer factory sim (falling-sand world, Godot later). Zach is building it with Claude, mostly by tuning browser prototypes conversationally. See README.md for the game and the controls.

## Workflow (Zach's choice)

- **This repo is the only source of truth.** Edit the prototypes here; don't publish them as separate Claude-hosted pages.
- **Commit and push straight to `main`** after each change Zach asks for, one commit per change, with a message saying what changed and why. GitHub Pages serves `main`, so the live links update a minute or two after a push:
  - https://zsmith1507.github.io/unholy-assembly/prototypes/proving-ground.html
  - https://zsmith1507.github.io/unholy-assembly/prototypes/charnel-pit.html
- **Before every push, run `node tools/smoke-test.js`.** It boots each prototype headlessly and runs ten seconds of game time; it must pass. For changes to behaviour or tuning, also measure the specific thing that changed with a quick headless script, and report the before/after numbers to Zach in plain terms.

## The prototypes

- Each prototype is one self-contained HTML file: inline CSS and JS, with Google Fonts the only external dependency. Keep them that way, so they open by double-click and on Pages.
- `prototypes/proving-ground.html` is the most current engine: Dig and Harvest spells, ragdolls, collapsing terrain, powder inertia, shading, and wind/force fields. `prototypes/charnel-pit.html` is the earlier physics sandbox and lacks those engine additions.
- Tuning numbers live in named config objects (`DIG`, `HARV`, `REND`, `CHUNK`, `WEIGHT`, `RAG`, `FOE`, `COLLAPSE`, `FRIC`, `MANA_*`, the per-material `DEF[...]` entries). When Zach asks to change how something feels, change the number in its config block rather than scattering literals, and tell him which knob it was.
- Mana regeneration is set very fast for demo purposes (`MANA_REGEN`, `MANA_DELAY`).
