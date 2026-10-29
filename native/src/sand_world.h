// SandWorld: the falling-sand grid every other system reads and writes.
// One cell per material grain. Coordinates are cells, x right, y down. (0,0) is the top-left of the world.
// The world is split into 64x64 chunks; only chunks that changed recently are simulated (sleeping chunks cost nothing).
//
// This is the stable API the rest of the game codes against. The Pixel Physics department extends the
// simulation behind it (velocity liquids, splashes, stains, heat, falling chunks) without changing these signatures.
#pragma once

#include "materials.h"

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <vector>

namespace godot {

class SandWorld : public RefCounted {
	GDCLASS(SandWorld, RefCounted)

public:
	static constexpr int CHUNK = 64;

	SandWorld();

	// --- setup ---
	void setup(int width, int height, int seed);
	int get_width() const { return w; }
	int get_height() const { return h; }
	int get_tick() const { return tick; }

	// --- simulation ---
	void step(); // one 60 Hz tick over the active chunks
	void wake_rect(int x, int y, int rw, int rh); // force chunks awake (after big external edits)
	int active_chunk_count() const;

	// --- cell access ---
	int get_mat(int x, int y) const; // out of bounds reads as BEDROCK
	void set_mat(int x, int y, int mat);
	void fill_rect(int x, int y, int rw, int rh, int mat);
	void paint_circle(int cx, int cy, int r, int mat, bool only_empty);
	bool in_bounds(int x, int y) const { return x >= 0 && y >= 0 && x < w && y < h; }
	bool is_solid(int x, int y) const; // characters collide with it (static and powder)
	bool is_liquid(int x, int y) const;
	bool is_empty(int x, int y) const; // air or gas
	int get_kind(int x, int y) const;

	// --- queries ---
	Vector2i raycast(Vector2i from, Vector2i to, bool stop_at_liquid) const; // first blocking cell, or (-1,-1)
	Dictionary count_rect(int x, int y, int rw, int rh) const; // {mat_id: count}
	int surface_y(int x, int from_y) const; // first solid cell at or below from_y in column x, or height

	// --- spells and damage ---
	// Wears down cells in a circle by `power` (Dig spell, ghoul shovels). Returns {mat_id: cells removed}.
	Dictionary dig(int cx, int cy, int r, float power);
	// Throws `count` grains of a liquid or powder at a point with a velocity (gore, splashes, spills).
	void spill(int x, int y, int mat, int count, float vx, float vy);
	void ignite(int x, int y, int r);
	void explode(int cx, int cy, int r, float force); // carve a crater, scatter debris, start fires
	// Ground that broke loose and is falling or just landed, since the last call: [{rect: Rect2i, force: float,
	// landed: bool, cells: int, speed: float}]. A falling chunk reports every tick it moves (rect = the cells it now
	// covers), and once more when it lands. force = speed (cells/tick) x cells x CRUSH.force_per. Ground only breaks
	// loose when dig(), explode() or fire cuts it free; nothing caves in by itself.
	Array take_crush_events();

	// --- added by Pixel Physics (beyond the original contract) ---
	float get_heat(int x, int y) const; // heat at a cell (about 7 lights wood, 3 tallow, 1.5 flashes miasma)
	void add_heat(int cx, int cy, int r, float amount); // warm a circle (furnaces, fire spells); can ignite things
	int get_stain(int x, int y) const; // which liquid has stained this cell (0 = clean)
	bool is_burning(int x, int y) const; // a solid, powder or liquid cell that is on fire right now
	int falling_chunk_count() const { return (int)bodies.size(); }
	int particle_count() const { return (int)particles.size(); }

	// --- rendering ---
	// Writes the cells in [x0, x0+image.width) x [y0, y0+image.height) into an RGBA8 image.
	void render_region(const Ref<Image> &image, int x0, int y0);
	// Same region, but only emissive cells, as a light map (RGB = light colour, A = strength).
	void render_glow(const Ref<Image> &image, int x0, int y0);

	// --- save and load ---
	PackedByteArray get_cells() const;
	void set_cells(const PackedByteArray &cells);

	// --- material info (static) ---
	static String mat_name(int mat);
	static int mat_kind(int mat);
	static float mat_hardness(int mat);

protected:
	static void _bind_methods();

private:
	struct Particle {
		float x, y, vx, vy;
		uint8_t mat, shade, mx_t, mx_a;
	};
	struct Body {
		uint16_t id;
		std::vector<int> cells;
		float vy = 0, acc = 0;
		int fell = 0, wait = 0;
	};

	int w = 0, h = 0, cw = 0, chh = 0, n = 0;
	int tick = 0;
	uint32_t rng = 0x9e3779b9u;

	// per cell (the prototype's arrays, same names where possible)
	std::vector<uint8_t> mat; // material id (prototype `type`)
	std::vector<uint8_t> shade; // colour variation 0-255
	std::vector<int16_t> life; // gas and flame lifetime
	std::vector<uint32_t> stamp; // tick the cell last moved (stops double updates)
	std::vector<int8_t> vy, vx; // powder fall speed; liquid flow direction
	std::vector<float> fvx, fvy; // liquid velocity, cells per tick
	std::vector<uint8_t> plg; // liquid plunge: 255 falling through air, 254 a landing droplet, else plunge left in a pool
	std::vector<uint8_t> mov; // powders: 1 moving, 0 resting
	std::vector<uint16_t> burn; // fuel left while burning (0 = not burning)
	std::vector<uint16_t> body_of; // which falling chunk this ground belongs to
	std::vector<uint8_t> st_t, st_i; // stain: which liquid, strength
	std::vector<uint16_t> st_l; // stain: ticks left
	std::vector<uint8_t> mx_t, mx_a; // liquid mix: the other liquid, its share 0-255
	std::vector<float> heat, heat2; // heat field: belongs to the place, not the cell
	std::vector<float> wear; // dig damage

	// per chunk
	std::vector<uint8_t> active, active_next; // simulate this tick / next tick
	std::vector<uint8_t> hot; // has heat to spread
	std::vector<uint8_t> zone; // scratch for heat_step
	std::vector<uint8_t> has_liquid; // a sleeping chunk with liquid still soaks, stains and mixes now and then
	std::vector<uint8_t> has_stain; // stains to age

	std::vector<Particle> particles;
	std::vector<Body> bodies;
	uint16_t next_body = 1;
	std::vector<int> collapse_seeds;
	std::vector<uint32_t> fill_mark;
	uint32_t fill_stamp = 1;
	std::vector<int> region_buf, stack_buf;
	Array crush_events;
	int fall_to = 0, impact = 0; // results of fall()

	inline int idx(int x, int y) const { return y * w + x; }
	inline int chunk_of(int i) const { return ((i / w) >> 6) * cw + ((i % w) >> 6); }
	inline uint32_t rnd_u() {
		rng ^= rng << 13;
		rng ^= rng >> 17;
		rng ^= rng << 5;
		return rng;
	}
	inline float rnd() { return (rnd_u() >> 8) * (1.0f / 16777216.0f); }
	inline bool is_open_i(int j) const { // air, gas or flame: things can move into it
		uint8_t k = unholy::md(mat[j]).kind;
		return k == unholy::K_EMPTY || k == unholy::K_GAS || k == unholy::K_FIRE;
	}

	void wake_at(int x, int y);
	inline void wake_i(int i) { wake_at(i % w, i / w); }
	void put(int i, int m); // prototype set(): resets everything about the cell
	void set_flame(int i, int lo, int hi);
	void swap_cells(int a, int b);
	inline void add_heat_i(int i, float v) {
		heat[i] += v;
		hot[chunk_of(i)] = 1;
	}
	void seed_collapse(int i) { collapse_seeds.push_back(i); }

	void update_cell(int i, int x, int y);
	int rand_neighbor(int i, int x, int y);
	void mix_cells(int i, int j);
	bool put_stain(int j, int t, float s);
	void stain_at(int j, int t, float boost = 1.0f);
	void splatter(int hit, int t, float dx, float dy, float speed);
	bool soak_into(int j, int t);
	void decay_stains(int by);
	bool launch(int i, float svx, float svy);
	void crown(int b, int x, float v);
	int fall(int i, int x, int t);
	void wake_above(int i);
	void update_powder(int i, int x, int y, int t);
	void update_liquid(int i, int x, int y, int t);
	bool liquid_side_effects(int i, int x, int y, int &t);
	void plunge_through(int cur, int b, int x, float v, bool spray);
	int flow(int i, int x, int dir, int dist, float d);
	void update_gas(int i, int x, int y, int t);
	void update_fire(int i, int x, int y);
	void emit_flame(int i, int x, int y, bool big);
	bool update_burning(int i, int x, int y, int t);
	bool has_air(int i) const;
	bool air_reach(int i, int t) const;
	bool airborne(int i, int t) const;
	void start_burn(int j);
	float air_heat(int i) const;
	void heat_step();
	void sleeping_liquids();
	void step_particles();
	void crumble(int i, int t);

	// collapsing ground
	int flood_region(int start);
	void process_collapse();
	void break_loose(int count);
	void step_bodies();
	void land(Body &b);
	void push_crush(const Body &b, bool landed);
};

} // namespace godot
