// Material table for the Unholy Assembly pixel simulation.
// IDs 0-21 match prototypes/proving-ground.html so tuning carries over; the rest are new for the game world.
// Add a material: give it an ID below MAT_COUNT, then a row in materials.cpp. Nothing else needs to change.
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
	float flammability = 0.0f; // chance per tick to catch when touching fire (0 = never)
	uint8_t dispersion = 0; // liquids: cells of sideways flow per tick
	float viscosity = 0.0f; // liquids: chance to sit still a tick
	uint16_t life_min = 0, life_max = 0; // gas and fire lifetime in ticks
	uint32_t colors[4] = { 0, 0, 0, 0 }; // 0xRRGGBB variations, picked per cell
	bool emissive = false; // glows in the dark (feeds the light map)
	bool solid_for_actors = false; // characters stand on it and collide with it
};

void init_materials();
const MatDef &mat_def(int id);

} // namespace unholy
