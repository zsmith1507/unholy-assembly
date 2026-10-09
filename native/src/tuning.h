// Tuning for the Unholy Assembly pixel simulation.
// These blocks carry the names Zach tuned in prototypes/proving-ground.html (COLLAPSE, FRIC, SKID, SOAK, the
// per-material fire and stain entries, MIX_PAIRS, SHADE), with the same numbers unless a comment says otherwise.
// To change how something feels, change the number here and rebuild; nothing else needs to move.
//
// Units: cells (2x2 px) and ticks (60 a second). "Chance" values are per cell per tick.
// On screen a cell is the same size as in the prototype (4 screen px at 1280x720), so speeds look the same.
#pragma once
#include "materials.h"

namespace unholy {
namespace tune {

struct MatVal {
	uint8_t mat;
	float v;
};

// ---------------------------------------------------------------- liquids
// Accelerating fall, cells per tick. Per-liquid flow (disp, visc, spl) lives in each material's row in materials.cpp.
struct LiquidTune {
	float gravity = 0.32f; // G_LIQ: speed gained per tick while falling
	int maxv = 7; // MAXV: terminal speed for liquids and powders
	float crown_min = 3.5f; // a fall this fast breaks the pool surface and throws a crown of droplets
	float splat_min = 3.0f; // a landing this hard on solid ground splats sideways or throws a droplet
};
constexpr LiquidTune LIQ{};

// Miscible pairs: chance per tick that touching cells trade concentration. Pairs not listed never blend.
struct MixPair {
	uint8_t a, b;
	float rate;
};
constexpr MixPair MIX_PAIRS[] = {
	{ BLOOD, HOLY, 0.16f }, // blood thins into holy water
	{ BLOOD, ICHOR, 0.04f }, // ichor slowly taints blood
	{ BLOOD, EMBALM, 0.10f }, // embalming fluid thins blood (new)
	{ HOLY, EMBALM, 0.12f }, // (new)
};

// ---------------------------------------------------------------- powders
// FRIC: chance per tick a sliding grain comes to rest. Higher piles steeper. Everything not listed uses FRIC_DEFAULT.
constexpr float FRIC_DEFAULT = 0.08f;
constexpr MatVal FRIC[] = {
	{ DIRT, 0.10f }, { RUBBLE, 0.14f }, { BONEBIT, 0.11f }, { ASH, 0.015f }, { EMBER, 0.03f },
	{ FLESH, 0.55f }, { MUD, 0.6f },
	{ SAND, 0.05f }, { SNOW, 0.2f }, { GIBS, 0.5f }, // new materials
};
// SKID: fine stuff skids sideways off a slope before it stops, so it lies flatter.
constexpr MatVal SKID[] = { { ASH, 0.55f }, { EMBER, 0.3f }, { SAND, 0.15f } };
// SLUMP: chance per tick a sliding grain actually moves (flesh slumps, mud is sluggish). Not listed = always.
constexpr MatVal SLUMP[] = { { FLESH, 0.12f }, { MUD, 0.35f }, { GIBS, 0.15f } };

// ---------------------------------------------------------------- stains
// pen: how far an impact drives the stain into a surface (times impact speed). p: chance per contact tick to mark
// a surface. ticks: how long it lasts. a: how dark it gets. Fresh -> aged colour over the first `age_by` of its
// life; it fades out over the last `fade_by`. glow: young stains glow. cleans: scrubs other stains away.
struct StainDef {
	uint8_t mat;
	float pen, p;
	int ticks;
	float a;
	uint32_t fresh, aged;
	float age_by, fade_by;
	bool glow, cleans;
};
constexpr StainDef STAIN[] = {
	{ BLOOD, 1.0f, 0.10f, 21600, 0.85f, 0x6e0d12, 0x3f2617, 0.30f, 0.25f, false, false }, // red ~1.8 min, gone at 6 min
	{ ICHOR, 0.6f, 0.06f, 7200, 0.70f, 0x6f9a1e, 0x46521d, 0.50f, 0.40f, true, false },
	{ TALLOW, 0.7f, 0.05f, 10800, 0.45f, 0xcdb87e, 0x7a683e, 0.60f, 0.30f, false, false },
	{ HOLY, 1.0f, 0.04f, 900, 0.40f, 0x14202c, 0x1a1f26, 1.00f, 0.70f, false, true },
	{ EMBALM, 0.8f, 0.05f, 5400, 0.40f, 0x2c4f4b, 0x3a4a40, 0.60f, 0.40f, false, false }, // new
};
// SOAK: how readily a surface soaks a stain in. Porous ground drinks it deep, stone and bone keep it on the surface.
constexpr MatVal SOAK[] = {
	{ STONE, 0.3f }, { BONE, 0.4f }, { WOOD, 0.75f }, { EMBER, 0.5f }, { DIRT, 1.1f }, { MUD, 0.9f }, { ASH, 1.3f },
	{ FLESH, 1.0f }, { EARTH, 0.9f }, { RUBBLE, 0.6f }, { BEDROCK, 0.15f }, { BONEBIT, 0.4f },
	{ GRASS, 0.9f }, { LEAVES, 0.8f }, { PLANK, 0.7f }, { BRICK, 0.35f }, { SAND, 1.2f }, { SNOW, 1.0f },
	{ GIBS, 1.0f }, { CLAY, 0.5f },
};
// ABSORB (new, from the design doc: "soil soaks liquids up, but stone holds them"): chance per tick that a liquid cell
// touching this ground is drunk into it. Each ground cell holds about three cells of liquid (it shows as a dark wet
// stain), passing the rest a few cells deeper; it can drink again once the stain dries. Not listed = holds liquid.
constexpr MatVal ABSORB[] = {
	{ EARTH, 0.0025f }, { DIRT, 0.006f }, { GRASS, 0.003f }, { SAND, 0.012f }, { ASH, 0.008f }, { RUBBLE, 0.002f },
	{ SNOW, 0.004f }, { GIBS, 0.002f },
};
struct SoilTune {
	int per_cell = 80; // wetness a ground cell gains per liquid cell it drinks (0-255)
	int full = 200; // at this wetness it is full and passes liquid deeper
	int depth = 3; // how many cells down liquid can seep past full ground
	float mud = 0.3f; // chance grave dirt full of blood or water turns to mud
	int sleeping_every = 4; // a still pool asleep is checked for soaking/mixing this often (ticks)
};
constexpr SoilTune SOIL{};

// ---------------------------------------------------------------- fire and heat
// ign: heat a cell must soak up before it catches (lower = catches sooner). fuel: ticks it burns. heat: heat it
// gives off per tick while burning. flame: chance per tick to throw a flame. burn_depth (liquids): how many layers
// below a pool's surface can burn at once. air_ign / air_burn: airborne fat (tallow) flashes.
struct FireDef {
	uint8_t mat;
	float ign;
	int fuel0, fuel1;
	float heat, flame;
	int burn_depth;
	float air_ign, air_burn;
};
constexpr float CATCH_SCALE = 0.25f; // chance per tick a flame lights touching fuel: CATCH_SCALE / (1 + ign)^2 (wood ~0.4%, tallow ~1.6%)
constexpr float FUEL_FLAME = 0.08f; // burning fuel throws a flame into the air above this often
constexpr float EMBER_LEAVE = 0.35f; // share of burnt-out timber/flesh cells that leave a glowing ember
constexpr FireDef FIRE[] = {
	{ WOOD, 7, 900, 1500, 3.2f, 0.09f, 1, 0, 0 }, // coffin wood: catches slowly, burns ~20 s, sheds embers
	{ FLESH, 5, 300, 520, 3.4f, 0.07f, 1, 0, 0 },
	{ TALLOW, 3, 100, 165, 3.4f, 0.12f, 3, 1.2f, 20 }, // pools burn from the surface down; droplets flash
	{ EMBER, 0, 120, 320, 1.4f, 0.025f, 1, 0, 0 },
	// new materials
	{ PLANK, 7, 800, 1300, 3.2f, 0.09f, 1, 0, 0 },
	{ LEAVES, 3, 40, 90, 3.0f, 0.15f, 1, 0, 0 },
	{ GRASS, 5, 60, 140, 2.0f, 0.08f, 1, 0, 0 },
	{ GIBS, 5, 300, 520, 3.4f, 0.07f, 1, 0, 0 },
	{ EMBALM, 4, 70, 120, 3.0f, 0.10f, 2, 1.5f, 12 }, // embalming fluid is spirit: it burns, and flashes when thrown
};
// Heat soaks into whatever is there, spreads to neighbours (mostly upward: hot air rises), and cools off.
struct HeatTune {
	// share passed on per tick, by kind: static, powder, liquid, air/gas
	float spread_static = 0.12f, spread_powder = 0.15f, spread_liquid = 0.2f, spread_air = 0.4f;
	// how well a cell takes heat in
	float cond_static = 0.35f, cond_powder = 0.3f, cond_liquid = 0.25f, cond_air = 1.0f, cond_stone = 0.2f, cond_tallow = 0.3f;
	// share lost per tick
	float cool_static = 0.012f, cool_powder = 0.02f, cool_liquid = 0.1f, cool_air = 0.045f, cool_tallow = 0.03f;
	float up = 0.5f, side = 0.18f, down = 0.14f; // where spread heat goes
	float flame = 5.0f; // a flame heats the air it is in by this much per tick
	float miasma_flash = 1.5f; // miasma this hot goes up in a flash
	float ichor_boil = 12.0f; // ichor this hot boils off into miasma
	float holy_boil = 22.0f; // holy water this hot turns to steam
	float snow_melt = 6.0f; // snow this hot melts away to steam (new)
};
constexpr HeatTune HEAT{};

// ---------------------------------------------------------------- collapsing ground
// Whenever ground is dug or blown away, the solid ground around the cut is flood-filled. If that patch no longer
// connects to bedrock or the edge of the world, it breaks off: crumbs fall as loose material, bigger pieces fall as
// one chunk that keeps its shape, pushes through liquid, crushes what's under it, and shatters on a hard landing.
// maxRegion is larger than the prototype's 2400 because the game's world is about 2.5x as fine around a character.
struct CollapseTune {
	int maxRegion = 6000; // bigger than this and it counts as part of the world
	int crumb = 8; // this many cells or fewer just crumbles
	int maxBodies = 40; // falling chunks at once
	int every = 3; // ticks between collapse checks
	float gravity = 0.18f; // speed a falling chunk gains per tick
	float shatter = 2.5f; // landing faster than this shatters the leading edge
	int seeds_per_check = 600;
};
constexpr CollapseTune COLLAPSE{};

// ---------------------------------------------------------------- digging (the C++ side; the spell's numbers live in necro/)
struct DigTune {
	float falloff = 0.6f; // the beam wears the edge of its circle this much slower than the middle
	float flesh_blood = 0.45f; // dug flesh bursts: this share turns to blood ...
	float flesh_tallow = 0.10f; // ... and this to tallow
};
constexpr DigTune DIG{};

// ---------------------------------------------------------------- shading (render_region)
// Ground gets a lit rim where it meets open air above, a shadow on undersides (tunnel ceilings, overhangs) and grows
// darker with depth; liquids get a bright surface line and darken toward the bottom of a pool.
struct ShadeTune {
	float rim = 1.24f, rim2 = 1.08f, deep = 0.035f, deepMax = 0.34f, under = 0.74f, side = 1.06f;
	float sheen = 1.28f, liqDeep = 0.03f, liqMax = 0.36f;
	float wear_max = 0.65f; // dug-at cells go pale this much at most
};
constexpr ShadeTune SHADE{};

} // namespace tune
} // namespace unholy
