// Material table for the Unholy Assembly pixel simulation.
// IDs 0-21 match prototypes/proving-ground.html so tuning carries over; the rest are new for the game world.
// Add a material: give it an ID below MAT_COUNT, then a row in materials.cpp. Behaviour tuning (friction, stains,
// burning, soaking) lives in tuning.h under the prototype's block names.
#pragma once
#include <cstdint>

namespace unholy {

enum Kind : uint8_t {
	K_EMPTY = 0,
	K_STATIC = 1, // holds its place: stone, packed earth, wood
	K_POWDER = 2, // falls and piles: grave dirt, ash, flesh, rubble
	K_LIQUID = 3, // falls and spreads: blood, holy water, ichor, tallow
	K_GAS = 4, // rises and fades: smoke, steam, miasma
	K_FIRE = 5, // short-lived flame
};

enum Mat : uint8_t {
	EMPTY = 0,
	STONE = 1,
	DIRT = 2, // grave dirt / loose soil
	ASH = 3,
	BONE = 4,
	FLESH = 5,
	WOOD = 6, // coffin wood, tree trunks
	BLOOD = 7,
	HOLY = 8, // holy water
	ICHOR = 9,
	TALLOW = 10,
	FIRE = 11,
	SMOKE = 12,
	STEAM = 13,
	MIASMA = 14,
	MUD = 15,
	SPOUT = 16, // reserved (prototype test emitter)
	EMBER = 17,
	EARTH = 18, // packed earth: the static body of the ground
	BEDROCK = 19,
	RUBBLE = 20,
	BONEBIT = 21, // bone shards
	// --- game world additions ---
	GRASS = 22, // static turf on the surface
	LEAVES = 23, // static foliage; burns fast
	PLANK = 24, // building timber
	BRICK = 25, // town walls, chapel stone
	SAND = 26,
	SNOW = 27,
	EMBALM = 28, // embalming fluid
	GIBS = 29, // processed flesh, powder
	CLAY = 30,
	MAT_COUNT = 64,
};

struct MatDef {
	const char *name = nullptr;
	Kind kind = K_EMPTY;
	float density = 0.0f; // heavier sinks through lighter liquids and powders
	float hardness = 0.0f; // how much Dig power it takes to wear away one cell (0 = cannot be dug)
	uint8_t dispersion = 0; // liquids: cells of sideways flow per tick (prototype `disp`)
	float viscosity = 0.0f; // liquids: chance to sit still a tick (prototype `visc`)
	float splash = 0.0f; // liquids: splashiness 0..1 (prototype `spl`)
	float rise = 0.0f; // gases: chance per tick to drift up
	float gas_alpha = 0.0f; // gases: how opaque
	uint16_t life_min = 0, life_max = 0; // gas and fire lifetime in ticks
	uint32_t colors[4] = { 0, 0, 0, 0 }; // 0xRRGGBB variations, picked per cell
	uint32_t glow = 0; // 0xRRGGBB light this material gives off by itself (feeds the glow map); 0 = none
	bool solid_for_actors = false; // characters stand on it and collide with it
	bool movable = false; // anything that isn't fixed ground

	// filled from tuning.h
	float fric = 0.08f, skid = 0.0f, slump = 1.0f; // powders
	float soak = 0.0f, absorb = 0.0f; // stains: how deep they soak in; liquids: how fast this ground drinks
	uint8_t loose = 0; // what it crumbles into when it breaks off (0 = stays itself)
	bool stains = false; // liquids that leave stains
	float st_pen = 0, st_p = 0;
	uint16_t st_ticks = 0;
	bool st_glow = false, st_cleans = false;
	uint8_t st_lut[64][4] = {}; // stain colour by age: r, g, b, alpha
	bool fueled = false; // burns (keeps its material while its fuel runs down)
	float ign = 0, bheat = 0, flamep = 0, air_ign = 0, air_burn = 0;
	uint16_t fuel0 = 0, fuel1 = 0;
	uint8_t burn_depth = 1;
	float spread = 0, cond = 0, cool = 0; // heat
};

void init_materials();
const MatDef &mat_def(int id);
float mix_rate(int a, int b); // chance per tick two liquids blend (0 = never)

} // namespace unholy
