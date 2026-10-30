#include "materials.h"
#include "tuning.h"

#include <algorithm>

namespace unholy {

MatDef g_defs[MAT_COUNT];
static float g_mix[MAT_COUNT][MAT_COUNT];
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
	d.movable = kind != K_STATIC;
	return d;
}

static void liquid(int id, uint8_t disp, float visc, float spl) {
	g_defs[id].dispersion = disp;
	g_defs[id].viscosity = visc;
	g_defs[id].splash = spl;
}

static void gas(int id, float rise, float alpha, uint16_t lo, uint16_t hi) {
	g_defs[id].rise = rise;
	g_defs[id].gas_alpha = alpha;
	g_defs[id].life_min = lo;
	g_defs[id].life_max = hi;
}

static inline int ch(uint32_t c, int s) {
	return (int)((c >> s) & 0xff);
}

void init_materials() {
	if (g_ready) {
		return;
	}
	g_ready = true;
	// name, kind, density, dig hardness, colours (prototype palette)
	g_defs[EMPTY] = def("Empty", K_EMPTY, 0, 0, 0, 0, 0, 0);
	g_defs[STONE] = def("Crypt Stone", K_STATIC, 99, 6.0f, 0x3b3a44, 0x34333c, 0x43414b, 0x2e2d35);
	g_defs[DIRT] = def("Grave Dirt", K_POWDER, 2.5f, 0.6f, 0x4a3526, 0x3f2d20, 0x56412f, 0x3a2a1d);
	g_defs[ASH] = def("Ash", K_POWDER, 1.5f, 0.3f, 0x6e6a66, 0x615d5a, 0x7a7672, 0x57534f);
	g_defs[BONE] = def("Bone", K_STATIC, 99, 3.0f, 0xd8ccaa, 0xcbbd98, 0xe2d8bb, 0xbfb08a);
	g_defs[FLESH] = def("Flesh", K_POWDER, 2.0f, 0.5f, 0x8f5b5a, 0x7f4d4e, 0x9c6764, 0x754546);
	g_defs[WOOD] = def("Coffin Wood", K_STATIC, 99, 2.0f, 0x4d3220, 0x432b1b, 0x573a26, 0x3b2618);

	g_defs[BLOOD] = def("Blood", K_LIQUID, 1.06f, 0, 0x7d0f14, 0x6e0c11, 0x8a1419, 0x650a0f);
	liquid(BLOOD, 8, 0.0f, 0.8f);
	g_defs[HOLY] = def("Holy Water", K_LIQUID, 1.0f, 0, 0x5d7a96, 0x577390, 0x6886a2, 0x52708b);
	liquid(HOLY, 11, 0.0f, 1.0f);
	g_defs[HOLY].glow = 0x06101c; // glow colours are the prototype's (G_HOLY etc.)
	g_defs[ICHOR] = def("Ichor", K_LIQUID, 1.3f, 0, 0x6f9a1e, 0x628a19, 0x7dab25, 0x587d15);
	liquid(ICHOR, 3, 0.35f, 0.18f);
	g_defs[ICHOR].glow = 0x225006;
	g_defs[TALLOW] = def("Tallow", K_LIQUID, 0.9f, 0, 0xc9b37a, 0xbea86f, 0xd4bf86, 0xb49d64);
	liquid(TALLOW, 6, 0.08f, 0.55f);

	g_defs[FIRE] = def("Fire", K_FIRE, -0.5f, 0, 0xe0602a, 0xf4a03a, 0xffd166, 0xa8331f);
	g_defs[FIRE].life_min = 20;
	g_defs[FIRE].life_max = 60;
	g_defs[FIRE].glow = 0xff9632;
	g_defs[SMOKE] = def("Smoke", K_GAS, -3, 0, 0x3a3638, 0x343033, 0x403c3e, 0x2f2b2d);
	gas(SMOKE, 0.7f, 0.55f, 60, 140);
	g_defs[STEAM] = def("Steam", K_GAS, -2, 0, 0xb8c4cc, 0xaebac2, 0xc2ced6, 0xa4b0b8);
	gas(STEAM, 0.85f, 0.4f, 70, 160);
	g_defs[MIASMA] = def("Miasma", K_GAS, -1, 0, 0x8a9a3a, 0x7f8f33, 0x95a541, 0x748429);
	gas(MIASMA, 0.3f, 0.5f, 400, 800);
	g_defs[MIASMA].glow = 0x1a2204;
	g_defs[MUD] = def("Mud", K_POWDER, 2.6f, 0.5f, 0x2f2219, 0x29201a, 0x36281d, 0x241a14);
	g_defs[SPOUT] = def("Spout", K_STATIC, 99, 0, 0x1f1c20, 0x1f1c20, 0x1f1c20, 0x1f1c20);
	g_defs[EMBER] = def("Ember", K_POWDER, 1.4f, 0.2f, 0xc4471c, 0xa8331f, 0xe0602a, 0x7a2414);
	g_defs[EMBER].glow = 0xe6641e;
	g_defs[EARTH] = def("Packed Earth", K_STATIC, 99, 1.2f, 0x3a2a20, 0x33251c, 0x412f24, 0x2d2018);
	g_defs[BEDROCK] = def("Bedrock", K_STATIC, 99, 0, 0x1d1b22, 0x18161c, 0x232028, 0x141217);
	g_defs[RUBBLE] = def("Rubble", K_POWDER, 2.8f, 0.8f, 0x4a4852, 0x3f3d46, 0x55535d, 0x36343c);
	g_defs[BONEBIT] = def("Bone Shards", K_POWDER, 2.2f, 0.4f, 0xcdbf9c, 0xbfb08a, 0xd8ccaa, 0xb3a47e);

	g_defs[GRASS] = def("Grass", K_STATIC, 99, 0.8f, 0x3d4a26, 0x36421f, 0x45532c, 0x2f3a1b);
	g_defs[LEAVES] = def("Leaves", K_STATIC, 99, 0.3f, 0x2c3a1f, 0x26331a, 0x334225, 0x1f2b15);
	g_defs[PLANK] = def("Plank", K_STATIC, 99, 1.8f, 0x5a4029, 0x4f3823, 0x654830, 0x45311e);
	g_defs[BRICK] = def("Brick", K_STATIC, 99, 5.0f, 0x5b4a44, 0x52423d, 0x66544d, 0x483a35);
	g_defs[SAND] = def("Sand", K_POWDER, 2.3f, 0.4f, 0x8a7a55, 0x7f704d, 0x95855e, 0x746645);
	g_defs[SNOW] = def("Snow", K_POWDER, 1.2f, 0.2f, 0xc8ccd2, 0xbcc1c8, 0xd2d6dc, 0xb0b5bc);
	g_defs[EMBALM] = def("Embalming Fluid", K_LIQUID, 1.1f, 0, 0x3f6f6a, 0x386560, 0x477a74, 0x315a56);
	liquid(EMBALM, 7, 0.02f, 0.7f);
	g_defs[GIBS] = def("Gibs", K_POWDER, 2.0f, 0.4f, 0x7a3f3f, 0x6c3636, 0x864848, 0x5f2f2f);
	g_defs[CLAY] = def("Clay", K_STATIC, 99, 1.6f, 0x5e4436, 0x553d30, 0x684c3d, 0x4b362a);
	{
		const tune::CoffinGrainTune &G = tune::COFFIN_GRAIN; // drawn from the grain, not these four (see coffin_rgb)
		g_defs[COFFIN] = def("Coffin Plank", K_STATIC, 99, 2.0f, G.dark, G.mid, G.light, G.seam);
	}

	// ---- tuning blocks (tuning.h) ----
	using namespace tune;
	for (int t = 0; t < MAT_COUNT; t++) {
		MatDef &d = g_defs[t];
		d.fric = FRIC_DEFAULT;
		switch (d.kind) {
			case K_STATIC:
				d.spread = HEAT.spread_static;
				d.cond = HEAT.cond_static;
				d.cool = HEAT.cool_static;
				break;
			case K_POWDER:
				d.spread = HEAT.spread_powder;
				d.cond = HEAT.cond_powder;
				d.cool = HEAT.cool_powder;
				break;
			case K_LIQUID:
				d.spread = HEAT.spread_liquid;
				d.cond = HEAT.cond_liquid;
				d.cool = HEAT.cool_liquid;
				break;
			default:
				d.spread = HEAT.spread_air;
				d.cond = HEAT.cond_air;
				d.cool = HEAT.cool_air;
				break;
		}
	}
	g_defs[TALLOW].cond = HEAT.cond_tallow;
	g_defs[TALLOW].cool = HEAT.cool_tallow;
	g_defs[STONE].cond = HEAT.cond_stone;
	g_defs[BRICK].cond = HEAT.cond_stone;

	for (const MatVal &v : FRIC) {
		g_defs[v.mat].fric = v.v;
	}
	for (int t = 0; t < MAT_COUNT; t++) {
		g_defs[t].repose = (uint8_t)REPOSE_DEFAULT;
	}
	for (const MatVal &v : REPOSE) {
		g_defs[v.mat].repose = (uint8_t)v.v;
	}
	for (const MatVal &v : SKID) {
		g_defs[v.mat].skid = v.v;
	}
	for (const MatVal &v : SLUMP) {
		g_defs[v.mat].slump = v.v;
	}
	for (const MatVal &v : SOAK) {
		g_defs[v.mat].soak = v.v;
	}
	for (const MatVal &v : ABSORB) {
		g_defs[v.mat].absorb = v.v;
	}
	for (const StainDef &s : STAIN) {
		MatDef &d = g_defs[s.mat];
		d.stains = true;
		d.st_pen = s.pen;
		d.st_p = s.p;
		d.st_ticks = (uint16_t)s.ticks;
		d.st_glow = s.glow;
		d.st_cleans = s.cleans;
		for (int k = 0; k < 64; k++) {
			float age = k / 63.0f; // 0 fresh .. 1 gone
			float m = std::min(1.0f, age / s.age_by);
			float a = s.a * (age < 1 - s.fade_by ? 1.0f : std::max(0.0f, (1 - age) / s.fade_by));
			for (int c = 0; c < 3; c++) {
				int sh = 16 - c * 8;
				d.st_lut[k][c] = (uint8_t)(ch(s.fresh, sh) + (ch(s.aged, sh) - ch(s.fresh, sh)) * m);
			}
			d.st_lut[k][3] = (uint8_t)(a * 255);
		}
	}
	for (const FireDef &f : tune::FIRE) {
		MatDef &d = g_defs[f.mat];
		d.fueled = true;
		d.ign = f.ign;
		d.fuel0 = (uint16_t)f.fuel0;
		d.fuel1 = (uint16_t)f.fuel1;
		d.bheat = f.heat;
		d.flamep = f.flame;
		d.burn_depth = (uint8_t)f.burn_depth;
		d.air_ign = f.air_ign;
		d.air_burn = f.air_burn;
	}
	for (int a = 0; a < MAT_COUNT; a++) {
		for (int b = 0; b < MAT_COUNT; b++) {
			g_mix[a][b] = 0;
		}
	}
	for (const MixPair &p : MIX_PAIRS) {
		g_mix[p.a][p.b] = p.rate;
		g_mix[p.b][p.a] = p.rate;
	}
	// what ground crumbles into when a piece breaks off or shatters
	g_defs[EARTH].loose = DIRT;
	g_defs[STONE].loose = RUBBLE;
	g_defs[BONE].loose = BONEBIT;
	g_defs[GRASS].loose = DIRT;
	g_defs[CLAY].loose = DIRT;
	g_defs[BRICK].loose = RUBBLE;
}

static inline uint32_t hash2(int x, int y, uint32_t salt) {
	uint32_t h = (uint32_t)x * 0x8da6b343u ^ (uint32_t)y * 0xd8163841u ^ salt * 0xcb1ab31fu;
	h ^= h >> 13;
	h *= 0x5bd1e995u;
	h ^= h >> 15;
	return h;
}

// shade: 0-15 seam or knot core, 16-255 dark .. mid .. light wood
uint8_t coffin_grain(int x, int y) {
	const tune::CoffinGrainTune &G = tune::COFFIN_GRAIN;
	int board = y >= 0 ? y / G.board : (y - G.board + 1) / G.board;
	int row = y - board * G.board;
	if (row == 0) {
		return 6; // seam between boards (render_region draws it only inside thick planking)
	}
	int off = (int)(hash2(board, 0, 7) % (uint32_t)G.length);
	int run = x + off;
	int seg = run >= 0 ? run / G.length : (run - G.length + 1) / G.length;
	if (run - seg * G.length == 0) {
		return 10; // butt joint
	}
	if ((hash2(x, y, 3) & 0xffff) < (uint32_t)(G.knot * 65536)) {
		return 2; // knot
	}
	// each board its own tone; long streaks along x (coarse noise, smoothed over a few cells)
	float tone = 0.45f + ((hash2(board, seg, 11) & 255) / 255.0f - 0.5f) * 0.3f;
	int s0 = (x + (int)(hash2(board, row, 5) & 15)) >> 2;
	float f = ((x + (int)(hash2(board, row, 5) & 15)) & 3) / 4.0f;
	float n0 = (hash2(s0, board * 8 + row, 13) & 255) / 255.0f, n1 = (hash2(s0 + 1, board * 8 + row, 13) & 255) / 255.0f;
	tone += (n0 + (n1 - n0) * f - 0.5f) * 2.0f * G.streak;
	tone = std::min(1.0f, std::max(0.0f, tone));
	return (uint8_t)(16 + tone * 239);
}

void coffin_rgb(uint8_t shade, float &r, float &g, float &b) {
	const tune::CoffinGrainTune &G = tune::COFFIN_GRAIN;
	if (shade < 16) {
		r = (float)ch(G.seam, 16);
		g = (float)ch(G.seam, 8);
		b = (float)ch(G.seam, 0);
		return;
	}
	float t = (shade - 16) / 239.0f;
	uint32_t a = t < 0.5f ? G.dark : G.mid, c = t < 0.5f ? G.mid : G.light;
	float k = t < 0.5f ? t * 2 : t * 2 - 1;
	r = ch(a, 16) + (ch(c, 16) - ch(a, 16)) * k;
	g = ch(a, 8) + (ch(c, 8) - ch(a, 8)) * k;
	b = ch(a, 0) + (ch(c, 0) - ch(a, 0)) * k;
}

const MatDef &mat_def(int id) {
	if (id < 0 || id >= MAT_COUNT) {
		return g_defs[EMPTY];
	}
	return g_defs[id];
}

float mix_rate(int a, int b) {
	return g_mix[a & 63][b & 63];
}

} // namespace unholy
