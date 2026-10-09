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
		uint8_t mat;
	};

	int w = 0, h = 0, cw = 0, chh = 0;
	int tick = 0;
	uint32_t rng = 0x9e3779b9u;

	std::vector<uint8_t> mat; // material id
	std::vector<uint8_t> shade; // colour variation 0-255
	std::vector<uint16_t> life; // gas and fire lifetime
	std::vector<float> wear; // dig damage
	std::vector<uint32_t> stamp; // tick the cell last moved (stops double updates)
	std::vector<uint8_t> active, active_next; // per chunk
	std::vector<Particle> particles;

	inline int idx(int x, int y) const { return y * w + x; }
	inline uint32_t rnd_u() {
		rng ^= rng << 13;
		rng ^= rng >> 17;
		rng ^= rng << 5;
		return rng;
	}
	inline float rnd() { return (rnd_u() >> 8) * (1.0f / 16777216.0f); }

	void wake_at(int x, int y);
	void put(int i, int m);
	void swap_cells(int a, int b);
	void update_cell(int x, int y, bool left_first);
	void update_powder(int x, int y, int i, bool lf);
	void update_liquid(int x, int y, int i, bool lf);
	void update_gas(int x, int y, int i, bool lf);
	void update_fire(int x, int y, int i);
	bool can_displace(int m, int target) const;
	void step_particles();
};

} // namespace godot
