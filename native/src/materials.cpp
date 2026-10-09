#include "materials.h"

namespace unholy {

static MatDef g_defs[MAT_COUNT];
static bool g_ready = false;

static MatDef def(const char *name, Kind kind, float dens, float hard, uint32_t c0, uint32_t c1, uint32_t c2, uint32_t c3) {
	MatDef d;
	d.name = name;
	d.kind = kind;
	d.density = dens;
	d.hardness = hard;
	d.colors[0] = c0;
	d.colors[1] = c1;
	d.colors[2] = c2;
	d.colors[3] = c3;
	d.solid_for_actors = (kind == K_STATIC || kind == K_POWDER);
	return d;
}

void init_materials() {
	if (g_ready) {
		return;
	}
	g_ready = true;
	g_defs[EMPTY] = def("Empty", K_EMPTY, 0, 0, 0, 0, 0, 0);
	g_defs[STONE] = def("Crypt Stone", K_STATIC, 99, 6.0f, 0x3b3a44, 0x34333c, 0x43414b, 0x2e2d35);
	g_defs[DIRT] = def("Grave Dirt", K_POWDER, 2.5f, 0.6f, 0x4a3526, 0x3f2d20, 0x56412f, 0x3a2a1d);
	g_defs[ASH] = def("Ash", K_POWDER, 1.5f, 0.3f, 0x6e6a66, 0x615d5a, 0x7a7672, 0x57534f);
	g_defs[BONE] = def("Bone", K_STATIC, 99, 3.0f, 0xd8ccaa, 0xcbbd98, 0xe2d8bb, 0xbfb08a);
	g_defs[FLESH] = def("Flesh", K_POWDER, 2.0f, 0.5f, 0x8f5b5a, 0x7f4d4e, 0x9c6764, 0x754546);
	g_defs[FLESH].flammability = 0.01f;
	g_defs[WOOD] = def("Wood", K_STATIC, 99, 2.0f, 0x4d3220, 0x432b1b, 0x573a26, 0x3b2618);
	g_defs[WOOD].flammability = 0.02f;

	g_defs[BLOOD] = def("Blood", K_LIQUID, 1.06f, 0.2f, 0x7d0f14, 0x6e0c11, 0x8a1419, 0x650a0f);
	g_defs[BLOOD].dispersion = 8;
	g_defs[HOLY] = def("Holy Water", K_LIQUID, 1.0f, 0.2f, 0x5d7a96, 0x577390, 0x6886a2, 0x52708b);
	g_defs[HOLY].dispersion = 11;
	g_defs[ICHOR] = def("Ichor", K_LIQUID, 1.3f, 0.2f, 0x6f9a1e, 0x628a19, 0x7dab25, 0x587d15);
	g_defs[ICHOR].dispersion = 3;
	g_defs[ICHOR].viscosity = 0.35f;
	g_defs[ICHOR].emissive = true;
	g_defs[TALLOW] = def("Tallow", K_LIQUID, 0.9f, 0.2f, 0xc9b37a, 0xbea86f, 0xd4bf86, 0xb49d64);
	g_defs[TALLOW].dispersion = 6;
	g_defs[TALLOW].viscosity = 0.08f;
	g_defs[TALLOW].flammability = 0.08f;

	g_defs[FIRE] = def("Fire", K_FIRE, -0.5f, 0, 0xe0602a, 0xf4a03a, 0xffd166, 0xa8331f);
	g_defs[FIRE].life_min = 20;
	g_defs[FIRE].life_max = 60;
	g_defs[FIRE].emissive = true;
	g_defs[SMOKE] = def("Smoke", K_GAS, -3, 0, 0x3a3638, 0x343033, 0x403c3e, 0x2f2b2d);
	g_defs[SMOKE].life_min = 60;
	g_defs[SMOKE].life_max = 140;
	g_defs[STEAM] = def("Steam", K_GAS, -2, 0, 0xb8c4cc, 0xaebac2, 0xc2ced6, 0xa4b0b8);
	g_defs[STEAM].life_min = 70;
	g_defs[STEAM].life_max = 160;
	g_defs[MIASMA] = def("Miasma", K_GAS, -1, 0, 0x8a9a3a, 0x7f8f33, 0x95a541, 0x748429);
	g_defs[MIASMA].life_min = 400;
	g_defs[MIASMA].life_max = 800;
	g_defs[MUD] = def("Mud", K_POWDER, 2.6f, 0.5f, 0x2f2219, 0x29201a, 0x36281d, 0x241a14);
	g_defs[SPOUT] = def("Spout", K_STATIC, 99, 0, 0x1f1c20, 0x1f1c20, 0x1f1c20, 0x1f1c20);
	g_defs[EMBER] = def("Ember", K_POWDER, 1.4f, 0.2f, 0xc4471c, 0xa8331f, 0xe0602a, 0x7a2414);
	g_defs[EMBER].emissive = true;
	g_defs[EARTH] = def("Packed Earth", K_STATIC, 99, 1.2f, 0x3a2a20, 0x33251c, 0x412f24, 0x2d2018);
	g_defs[BEDROCK] = def("Bedrock", K_STATIC, 99, 0, 0x1d1b22, 0x18161c, 0x232028, 0x141217);
	g_defs[RUBBLE] = def("Rubble", K_POWDER, 2.8f, 0.8f, 0x4a4852, 0x3f3d46, 0x55535d, 0x36343c);
	g_defs[BONEBIT] = def("Bone Shards", K_POWDER, 2.2f, 0.4f, 0xcdbf9c, 0xbfb08a, 0xd8ccaa, 0xb3a47e);

	g_defs[GRASS] = def("Grass", K_STATIC, 99, 0.8f, 0x3d4a26, 0x36421f, 0x45532c, 0x2f3a1b);
	g_defs[GRASS].flammability = 0.01f;
	g_defs[LEAVES] = def("Leaves", K_STATIC, 99, 0.3f, 0x2c3a1f, 0x26331a, 0x334225, 0x1f2b15);
	g_defs[LEAVES].flammability = 0.05f;
	g_defs[PLANK] = def("Plank", K_STATIC, 99, 1.8f, 0x5a4029, 0x4f3823, 0x654830, 0x45311e);
	g_defs[PLANK].flammability = 0.02f;
	g_defs[BRICK] = def("Brick", K_STATIC, 99, 5.0f, 0x5b4a44, 0x52423d, 0x66544d, 0x483a35);
	g_defs[SAND] = def("Sand", K_POWDER, 2.3f, 0.4f, 0x8a7a55, 0x7f704d, 0x95855e, 0x746645);
	g_defs[SNOW] = def("Snow", K_POWDER, 1.2f, 0.2f, 0xc8ccd2, 0xbcc1c8, 0xd2d6dc, 0xb0b5bc);
	g_defs[EMBALM] = def("Embalming Fluid", K_LIQUID, 1.1f, 0.2f, 0x3f6f6a, 0x386560, 0x477a74, 0x315a56);
	g_defs[EMBALM].dispersion = 7;
	g_defs[GIBS] = def("Gibs", K_POWDER, 2.0f, 0.4f, 0x7a3f3f, 0x6c3636, 0x864848, 0x5f2f2f);
	g_defs[CLAY] = def("Clay", K_STATIC, 99, 1.6f, 0x5e4436, 0x553d30, 0x684c3d, 0x4b362a);
}

const MatDef &mat_def(int id) {
	if (id < 0 || id >= MAT_COUNT) {
		return g_defs[EMPTY];
	}
	return g_defs[id];
}

} // namespace unholy
