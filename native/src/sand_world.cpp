#include "sand_world.h"
#include "tuning.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/rect2i.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>

using namespace godot;
using namespace unholy;

SandWorld::SandWorld() {
	init_materials();
}

// ---------------------------------------------------------------- setup

void SandWorld::setup(int width, int height, int seed) {
	ERR_FAIL_COND_MSG(width < 16 || height < 16, "SandWorld.setup: world must be at least 16x16 cells.");
	w = width;
	h = height;
	n = w * h;
	cw = (w + CHUNK - 1) / CHUNK;
	chh = (h + CHUNK - 1) / CHUNK;
	tick = 0;
	rng = seed ? (uint32_t)seed : 0x9e3779b9u;
	const size_t N = (size_t)n, C = (size_t)cw * chh;
	mat.assign(N, EMPTY);
	shade.resize(N);
	for (size_t i = 0; i < N; i++) {
		shade[i] = (uint8_t)(rnd_u() & 0xff);
	}
	life.assign(N, 0);
	stamp.assign(N, 0);
	vy.assign(N, 0);
	vx.assign(N, 0);
	fvx.assign(N, 0.0f);
	fvy.assign(N, 0.0f);
	plg.assign(N, 0);
	mov.assign(N, 0);
	burn.assign(N, 0);
	body_of.assign(N, 0);
	st_t.assign(N, 0);
	st_i.assign(N, 0);
	st_l.assign(N, 0);
	mx_t.assign(N, 0);
	mx_a.assign(N, 0);
	heat.assign(N, 0.0f);
	heat2.assign(N, 0.0f);
	wear.assign(N, 0.0f);
	fill_mark.assign(N, 0);
	fill_stamp = 1;
	region_buf.assign(N, 0);
	stack_buf.assign(N, 0);
	active.assign(C, 1);
	active_next.assign(C, 1);
	hot.assign(C, 0);
	zone.assign(C, 0);
	has_liquid.assign(C, 0);
	has_stain.assign(C, 0);
	particles.clear();
	bodies.clear();
	collapse_seeds.clear();
	crush_events = Array();
	next_body = 1;
}

void SandWorld::wake_at(int x, int y) {
	int cx = x / CHUNK, cy = y / CHUNK;
	if (cx < 0 || cy < 0 || cx >= cw || cy >= chh) {
		return;
	}
	active_next[cy * cw + cx] = 1;
	// on a chunk edge, the neighbour may need to react too
	int lx = x % CHUNK, ly = y % CHUNK;
	if (lx == 0 && cx > 0) {
		active_next[cy * cw + cx - 1] = 1;
	}
	if (lx == CHUNK - 1 && cx < cw - 1) {
		active_next[cy * cw + cx + 1] = 1;
	}
	if (ly == 0 && cy > 0) {
		active_next[(cy - 1) * cw + cx] = 1;
	}
	if (ly == CHUNK - 1 && cy < chh - 1) {
		active_next[(cy + 1) * cw + cx] = 1;
	}
}

void SandWorld::wake_rect(int x, int y, int rw, int rh) {
	int x0 = std::max(0, x / CHUNK - 1), y0 = std::max(0, y / CHUNK - 1);
	int x1 = std::min(cw - 1, (x + rw) / CHUNK + 1), y1 = std::min(chh - 1, (y + rh) / CHUNK + 1);
	for (int cy = y0; cy <= y1; cy++) {
		for (int cx = x0; cx <= x1; cx++) {
			active_next[cy * cw + cx] = 1;
		}
	}
}

int SandWorld::active_chunk_count() const {
	int c = 0;
	for (uint8_t a : active_next) {
		c += a;
	}
	return c;
}

// ---------------------------------------------------------------- cell access

int SandWorld::get_mat(int x, int y) const {
	if (!in_bounds(x, y)) {
		return BEDROCK;
	}
	return mat[idx(x, y)];
}

void SandWorld::set_mat(int x, int y, int m) {
	if (!in_bounds(x, y) || m < 0 || m >= MAT_COUNT) {
		return;
	}
	put(idx(x, y), m);
}

void SandWorld::fill_rect(int x, int y, int rw, int rh, int m) {
	int x0 = std::max(0, x), y0 = std::max(0, y), x1 = std::min(w, x + rw), y1 = std::min(h, y + rh);
	for (int yy = y0; yy < y1; yy++) {
		for (int xx = x0; xx < x1; xx++) {
			put(idx(xx, yy), m);
		}
	}
}

void SandWorld::paint_circle(int cx, int cy, int r, int m, bool only_empty) {
	for (int yy = cy - r; yy <= cy + r; yy++) {
		for (int xx = cx - r; xx <= cx + r; xx++) {
			if (!in_bounds(xx, yy)) {
				continue;
			}
			int dx = xx - cx, dy = yy - cy;
			if (dx * dx + dy * dy > r * r) {
				continue;
			}
			int i = idx(xx, yy);
			if (only_empty && mat_def(mat[i]).kind != K_EMPTY && mat_def(mat[i]).kind != K_GAS) {
				continue;
			}
			put(i, m);
		}
	}
}

bool SandWorld::is_solid(int x, int y) const {
	if (!in_bounds(x, y)) {
		return true;
	}
	return mat_def(mat[idx(x, y)]).solid_for_actors;
}

bool SandWorld::is_liquid(int x, int y) const {
	return in_bounds(x, y) && mat_def(mat[idx(x, y)]).kind == K_LIQUID;
}

bool SandWorld::is_empty(int x, int y) const {
	if (!in_bounds(x, y)) {
		return false;
	}
	Kind k = mat_def(mat[idx(x, y)]).kind;
	return k == K_EMPTY || k == K_GAS;
}

int SandWorld::get_kind(int x, int y) const {
	if (!in_bounds(x, y)) {
		return K_STATIC;
	}
	return mat_def(mat[idx(x, y)]).kind;
}

// ---------------------------------------------------------------- queries

Vector2i SandWorld::raycast(Vector2i from, Vector2i to, bool stop_at_liquid) const {
	int x0 = from.x, y0 = from.y, x1 = to.x, y1 = to.y;
	int dx = std::abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
	int dy = -std::abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
	int err = dx + dy;
	while (true) {
		if (is_solid(x0, y0) || (stop_at_liquid && is_liquid(x0, y0))) {
			return Vector2i(x0, y0);
		}
		if (x0 == x1 && y0 == y1) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			x0 += sx;
		}
		if (e2 <= dx) {
			err += dx;
			y0 += sy;
		}
	}
	return Vector2i(-1, -1);
}

Dictionary SandWorld::count_rect(int x, int y, int rw, int rh) const {
	int counts[MAT_COUNT] = { 0 };
	int x0 = std::max(0, x), y0 = std::max(0, y), x1 = std::min(w, x + rw), y1 = std::min(h, y + rh);
	for (int yy = y0; yy < y1; yy++) {
		for (int xx = x0; xx < x1; xx++) {
			counts[mat[idx(xx, yy)]]++;
		}
	}
	Dictionary d;
	for (int m = 0; m < MAT_COUNT; m++) {
		if (counts[m]) {
			d[m] = counts[m];
		}
	}
	return d;
}

int SandWorld::surface_y(int x, int from_y) const {
	if (x < 0 || x >= w) {
		return h;
	}
	for (int y = std::max(0, from_y); y < h; y++) {
		if (is_solid(x, y)) {
			return y;
		}
	}
	return h;
}

// ---------------------------------------------------------------- spells and damage

void SandWorld::spill(int x, int y, int m, int count, float svx, float svy) {
	if (m <= 0 || m >= MAT_COUNT || !in_bounds(x, y)) {
		return;
	}
	Kind k = md(m).kind;
	if (k != K_LIQUID && k != K_POWDER) {
		return;
	}
	for (int c = 0; c < count && (int)particles.size() < tune::PART.max; c++) {
		Particle p;
		p.x = x + 0.5f;
		p.y = y + 0.5f;
		p.vx = svx + (rnd() - 0.5f) * 1.2f;
		p.vy = svy + (rnd() - 0.5f) * 1.2f;
		p.mat = (uint8_t)m;
		p.shade = (uint8_t)(rnd_u() & 0xff);
		p.mx_t = 0;
		p.mx_a = 0;
		particles.push_back(p);
	}
	wake_at(x, y);
}

// What digging leaves behind (prototype crumble): most dug ground vanishes, a little falls as loose grains; burning
// timber falls as an ember; flesh doesn't crumble, it bursts into blood and fat.
void SandWorld::crumble(int i, int t) {
	const tune::CrumbleTune &C = tune::CRUMBLE;
	float r = rnd();
	bool was_burning = burn[i] != 0;
	if (was_burning && (t == WOOD || t == PLANK || t == FLESH || t == GIBS)) {
		put(i, EMBER);
		burn[i] = (uint16_t)(120 + (int)(rnd() * 200));
	} else if (t == EARTH || t == GRASS) {
		put(i, r < C.earth_dirt ? DIRT : EMPTY);
	} else if (t == STONE) {
		put(i, r < C.stone_rubble ? RUBBLE : EMPTY);
	} else if (t == BRICK) {
		put(i, r < C.brick_rubble ? RUBBLE : EMPTY);
	} else if (t == BONE) {
		put(i, r < C.bone_shards ? BONEBIT : EMPTY);
	} else if (t == WOOD || t == PLANK) {
		put(i, r < C.wood_ash ? ASH : EMPTY);
	} else if (t == CLAY) {
		put(i, r < C.clay_dirt ? DIRT : EMPTY);
	} else if (t == FLESH || t == GIBS) {
		if (r < tune::DIG.flesh_blood) {
			put(i, BLOOD);
			fvx[i] = (rnd() - 0.5f) * 2.0f;
			fvy[i] = 0;
		} else if (r < tune::DIG.flesh_blood + tune::DIG.flesh_tallow) {
			put(i, TALLOW);
		} else {
			put(i, EMPTY);
		}
		int x = i % w, y = i / w;
		for (int k = 0; k < 3; k++) {
			int nx = x + (int)(rnd() * 3) - 1, ny = y + (int)(rnd() * 3) - 1;
			if (in_bounds(nx, ny) && (nx != x || ny != y)) {
				splatter(idx(nx, ny), BLOOD, (float)(nx - x), (float)(ny - y), 3);
			}
		}
	} else {
		put(i, EMPTY);
	}
}

Dictionary SandWorld::dig(int cx, int cy, int r, float power) {
	int removed[MAT_COUNT] = { 0 };
	r = std::max(0, r);
	for (int yy = cy - r; yy <= cy + r; yy++) {
		for (int xx = cx - r; xx <= cx + r; xx++) {
			if (!in_bounds(xx, yy)) {
				continue;
			}
			int dx = xx - cx, dy = yy - cy;
			float d2 = (float)(dx * dx + dy * dy);
			if (d2 > (float)(r * r)) {
				continue;
			}
			int i = idx(xx, yy);
			int t = mat[i];
			const MatDef &d = md(t);
			if ((d.kind != K_STATIC && d.kind != K_POWDER) || d.hardness <= 0) {
				continue; // air, liquids, bedrock
			}
			float falloff = 1.0f - tune::DIG.falloff * std::sqrt(d2) / (float)std::max(1, r);
			wear[i] += power * falloff;
			if (wear[i] >= d.hardness) {
				removed[t]++;
				bool was_static = d.kind == K_STATIC;
				crumble(i, t);
				if (was_static) {
					seed_collapse(i); // the cut may have freed a piece of ground
				}
			}
		}
	}
	Dictionary out;
	for (int m = 0; m < MAT_COUNT; m++) {
		if (removed[m]) {
			out[m] = removed[m];
		}
	}
	return out;
}

void SandWorld::ignite(int x, int y, int r) {
	r = std::max(0, r);
	for (int yy = y - r; yy <= y + r; yy++) {
		for (int xx = x - r; xx <= x + r; xx++) {
			if (!in_bounds(xx, yy)) {
				continue;
			}
			int dx = xx - x, dy = yy - y;
			if (dx * dx + dy * dy > r * r) {
				continue;
			}
			int i = idx(xx, yy);
			const MatDef &d = md(mat[i]);
			if (d.fueled) {
				if (mat[i] != EMBER && air_reach(i, mat[i])) {
					start_burn(i);
				}
			} else if (mat[i] == EMPTY && rnd() < 0.3f) {
				set_flame(i, 10, 30);
			}
			add_heat_i(i, 6.0f);
		}
	}
	wake_at(x, y);
}

void SandWorld::explode(int cx, int cy, int r, float force) {
	const tune::BlastTune &B = tune::BLAST;
	r = std::max(1, r);
	for (int yy = cy - r; yy <= cy + r; yy++) {
		for (int xx = cx - r; xx <= cx + r; xx++) {
			if (!in_bounds(xx, yy)) {
				continue;
			}
			int dx = xx - cx, dy = yy - cy;
			float dist = std::sqrt((float)(dx * dx + dy * dy));
			if (dist > r) {
				continue;
			}
			int i = idx(xx, yy);
			int t = mat[i];
			const MatDef &d = md(t);
			float k = force / std::max(1.0f, dist);
			if (d.kind == K_LIQUID) { // liquids are thrown, not destroyed
				launch(i, dx * k * B.liquid_speed * 0.25f, dy * k * B.liquid_speed * 0.25f - 1.0f);
				continue;
			}
			if (d.kind == K_EMPTY || d.kind == K_GAS) {
				if (dist > r * 0.75f && rnd() < B.rim_fire) {
					set_flame(i, 8, 24);
				} else if (rnd() < B.smoke * 0.5f) {
					put(i, SMOKE);
				}
				continue;
			}
			if (d.kind == K_FIRE || d.hardness <= 0) {
				continue; // bedrock
			}
			if (d.hardness > force * B.carve * (1.0f - dist / r)) {
				continue;
			}
			bool was_static = d.kind == K_STATIC;
			if (rnd() < B.debris) { // some of it flies as debris
				int deb = was_static ? (d.loose ? d.loose : (t == WOOD || t == PLANK ? EMBER : RUBBLE)) : t;
				put(i, deb);
				if (deb == EMBER) {
					burn[i] = (uint16_t)(150 + (int)(rnd() * 200));
				}
				float sp = force * B.debris_speed / std::max(1.0f, dist);
				if (launch(i, dx * sp * 0.25f, dy * sp * 0.25f - 1.5f)) {
					if (was_static) {
						seed_collapse(i);
					}
					continue;
				}
			}
			put(i, (dist > r * 0.75f && rnd() < B.rim_fire) ? FIRE : (rnd() < B.smoke ? SMOKE : EMPTY));
			if (was_static) {
				seed_collapse(i);
			}
		}
	}
	// the blast's heat: sets off anything flammable near the centre
	int hr = std::max(1, r / 2);
	for (int yy = cy - hr; yy <= cy + hr; yy++) {
		for (int xx = cx - hr; xx <= cx + hr; xx++) {
			if (in_bounds(xx, yy)) {
				add_heat_i(idx(xx, yy), B.heat * force / 10.0f);
			}
		}
	}
	wake_rect(cx - r, cy - r, r * 2 + 1, r * 2 + 1);
}

float SandWorld::get_heat(int x, int y) const {
	return in_bounds(x, y) ? heat[idx(x, y)] : 0.0f;
}

void SandWorld::add_heat(int cx, int cy, int r, float amount) {
	r = std::max(0, r);
	for (int yy = cy - r; yy <= cy + r; yy++) {
		for (int xx = cx - r; xx <= cx + r; xx++) {
			int dx = xx - cx, dy = yy - cy;
			if (in_bounds(xx, yy) && dx * dx + dy * dy <= r * r) {
				add_heat_i(idx(xx, yy), amount);
			}
		}
	}
	wake_at(cx, cy);
}

int SandWorld::get_stain(int x, int y) const {
	if (!in_bounds(x, y)) {
		return 0;
	}
	int i = idx(x, y);
	return st_l[i] ? st_t[i] : 0;
}

bool SandWorld::is_burning(int x, int y) const {
	return in_bounds(x, y) && burn[idx(x, y)] != 0;
}

// ---------------------------------------------------------------- collapsing ground
// Whenever ground is dug, burned or blown away, the solid ground around the cut is flood-filled. A patch that no
// longer connects to bedrock, the sides or the bottom of the world breaks off: crumbs fall apart into loose grains,
// bigger pieces fall as one chunk that keeps its shape, push through liquid, report crush events, and shatter on a
// hard landing. Nothing caves in by itself: only cuts seed the check.

static inline bool holds_together(int t) {
	return md(t).kind == K_STATIC && t != BEDROCK && t != SPOUT;
}

int SandWorld::flood_region(int start) {
	int sp = 0, cnt = 0;
	stack_buf[sp++] = start;
	fill_mark[start] = fill_stamp;
	const uint16_t sb = body_of[start];
	while (sp) {
		int q = stack_buf[--sp];
		if (cnt >= tune::COLLAPSE.maxRegion) {
			return -1; // too big to be loose: part of the world
		}
		region_buf[cnt++] = q;
		int x = q % w, y = q / w;
		if (x == 0 || x == w - 1 || y == h - 1) {
			return -1; // the edge of the world holds it up
		}
		int nb4[4] = { q - w, q + w, q - 1, q + 1 };
		for (int k = 0; k < 4; k++) {
			int nb = nb4[k];
			if (nb < 0 || nb >= n) {
				continue;
			}
			int tn = mat[nb];
			if (tn == BEDROCK || tn == SPOUT) {
				return -1; // anchored
			}
			if (holds_together(tn) && fill_mark[nb] != fill_stamp && (!body_of[nb] || body_of[nb] == sb)) {
				fill_mark[nb] = fill_stamp;
				stack_buf[sp++] = nb;
			}
		}
	}
	return cnt;
}

void SandWorld::process_collapse() {
	if (collapse_seeds.empty()) {
		return;
	}
	fill_stamp = fill_stamp >= 0xfffffffeu ? 1 : fill_stamp + 1;
	if (fill_stamp == 1) {
		std::fill(fill_mark.begin(), fill_mark.end(), 0);
	}
	int take = std::min((int)collapse_seeds.size(), tune::COLLAPSE.seeds_per_check);
	std::vector<int> seeds(collapse_seeds.begin(), collapse_seeds.begin() + take);
	collapse_seeds.erase(collapse_seeds.begin(), collapse_seeds.begin() + take);
	for (int sd : seeds) {
		if (sd < 0 || sd >= n) {
			continue;
		}
		int sx = sd % w;
		int nb4[5] = { sd, sd - w, sd + w, sx > 0 ? sd - 1 : -1, sx < w - 1 ? sd + 1 : -1 };
		for (int j : nb4) {
			if (j < 0 || j >= n || !holds_together(mat[j]) || body_of[j] || fill_mark[j] == fill_stamp) {
				continue;
			}
			int cnt = flood_region(j);
			if (cnt > 0) {
				break_loose(cnt);
			}
		}
	}
}

void SandWorld::break_loose(int count) {
	if (count <= tune::COLLAPSE.crumb) { // a crumb: it just falls apart
		for (int k = 0; k < count; k++) {
			int q = region_buf[k];
			int lt = md(mat[q]).loose;
			if (lt) {
				uint8_t sh = shade[q];
				put(q, lt);
				shade[q] = sh;
			}
		}
		int solid_left = 0;
		for (int k = 0; k < count; k++) {
			solid_left += holds_together(mat[region_buf[k]]) ? 1 : 0;
		}
		if (!solid_left) {
			return;
		}
	}
	if ((int)bodies.size() >= tune::COLLAPSE.maxBodies) {
		return;
	}
	Body b;
	b.id = next_body;
	next_body = next_body >= 65535 ? 1 : next_body + 1;
	b.cells.reserve(count);
	for (int k = 0; k < count; k++) {
		int q = region_buf[k];
		if (holds_together(mat[q])) {
			body_of[q] = b.id;
			b.cells.push_back(q);
		}
	}
	if (!b.cells.empty()) {
		wake_i(b.cells[0]);
		bodies.push_back(std::move(b));
	}
}

void SandWorld::push_crush(const Body &b, bool landed) {
	if (b.cells.empty()) {
		return;
	}
	int x0 = w, y0 = h, x1 = -1, y1 = -1;
	for (int q : b.cells) {
		int x = q % w, y = q / w;
		x0 = std::min(x0, x);
		x1 = std::max(x1, x);
		y0 = std::min(y0, y);
		y1 = std::max(y1, y);
	}
	Dictionary e;
	e["rect"] = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
	e["force"] = b.vy * (float)b.cells.size() * tune::CRUSH.force_per;
	e["landed"] = landed;
	e["cells"] = (int)b.cells.size();
	e["speed"] = b.vy;
	if (crush_events.size() >= tune::CRUSH.max_events) {
		crush_events.pop_front();
	}
	crush_events.push_back(e);
}

void SandWorld::land(Body &b) {
	const float v = b.vy;
	const float shatter = tune::COLLAPSE.shatter;
	if (v >= shatter) { // a hard landing: the leading edge shatters, and some of it bounces up as loose grains
		float chance = std::min(0.85f, (v - shatter + 0.6f) * 0.22f);
		for (int q : b.cells) {
			if (body_of[q] != b.id || (q + w < n && body_of[q + w] == b.id) || rnd() > chance) {
				continue;
			}
			int t = mat[q];
			int lt = md(t).loose ? md(t).loose : ((t == WOOD || t == PLANK) ? ASH : 0);
			if (!lt) {
				continue;
			}
			uint8_t sh = shade[q];
			put(q, lt);
			shade[q] = sh;
			if (rnd() < 0.3f && q >= w && is_open_i(q - w)) {
				launch(q, (rnd() - 0.5f) * 1.6f, -0.4f - rnd() * 0.9f);
			}
		}
	}
	push_crush(b, true);
	for (int q : b.cells) {
		if (body_of[q] == b.id) {
			body_of[q] = 0;
			mov[q] = 1;
			if (q < n - w) {
				mov[q + w] = 1;
			}
			wake_i(q);
		}
	}
}

// A chunk moves column by column: in each column it spans, everything from its top cell to its bottom cell shifts
// down together, so whatever is inside it (a coffin's occupant, a pocket of blood) rides along.
void SandWorld::step_bodies() {
	struct Col {
		int x, lo, hi;
	};
	std::vector<Col> cols;
	std::vector<int> col_of;
	for (int k = (int)bodies.size() - 1; k >= 0; k--) {
		Body &b = bodies[k];
		b.cells.erase(std::remove_if(b.cells.begin(), b.cells.end(), [&](int q) { return body_of[q] != b.id; }), b.cells.end());
		if (b.cells.empty()) {
			bodies.erase(bodies.begin() + k);
			continue;
		}
		b.vy = std::min((float)tune::LIQ.maxv, b.vy + tune::COLLAPSE.gravity);
		b.acc += b.vy;
		int steps = (int)std::floor(b.acc);
		b.acc -= steps;
		bool done = false;
		int moved = 0;
		if (steps > 0) {
			int xmin = w, xmax = -1;
			for (int q : b.cells) {
				xmin = std::min(xmin, q % w);
				xmax = std::max(xmax, q % w);
			}
			col_of.assign(xmax - xmin + 1, -1);
			cols.clear();
			for (int q : b.cells) {
				int x = q % w, y = q / w;
				int &c = col_of[x - xmin];
				if (c < 0) {
					c = (int)cols.size();
					cols.push_back({ x, y, y });
				} else {
					cols[c].lo = std::min(cols[c].lo, y);
					cols[c].hi = std::max(cols[c].hi, y);
				}
			}
		}
		while (steps-- > 0) {
			// can this chunk move down one cell? 1 = yes, 0 = it has landed, 2 = waiting on another falling chunk
			int can = 1;
			for (const Col &c : cols) {
				for (int y = c.lo + 1; y < c.hi && can == 1; y++) { // something of the world caught inside it: hooked on
					int q = y * w + c.x;
					if (body_of[q] == b.id) {
						continue;
					}
					if (body_of[q]) {
						can = 2;
					} else if (md(mat[q]).kind == K_STATIC) {
						can = 0;
					}
				}
				if (can != 1) {
					break;
				}
				int below = (c.hi + 1) * w + c.x;
				if (c.hi + 1 >= h) {
					can = 0;
					break;
				}
				if (body_of[below]) {
					can = 2;
					break;
				}
				if (!(is_open_i(below) || md(mat[below]).kind == K_LIQUID)) {
					can = 0;
					break;
				}
			}
			if (can == 1) {
				for (Col &c : cols) {
					for (int y = c.hi; y >= c.lo; y--) {
						swap_cells(y * w + c.x, (y + 1) * w + c.x);
					}
					c.lo++;
					c.hi++;
				}
				for (int &q : b.cells) {
					q += w;
				}
				b.fell++;
				moved++;
				continue;
			}
			if (can == 2) {
				b.vy = std::min(b.vy, 1.0f);
				b.acc = 0;
				if (++b.wait > 240) {
					land(b);
					done = true;
				}
				break;
			}
			land(b);
			done = true;
			break;
		}
		if (done) {
			bodies.erase(bodies.begin() + k);
		} else {
			wake_i(b.cells[0]);
			if (moved) {
				push_crush(b, false);
			}
		}
	}
}

Array SandWorld::take_crush_events() {
	Array out = crush_events;
	crush_events = Array();
	return out;
}

// ---------------------------------------------------------------- rendering
// The prototype's look: each cell's colour (with stains, liquid mixes, burning glow and dig wear blended in), then
// shading from its neighbours: ground gets a lit rim under open air, shadowed undersides and darkens with depth;
// liquids get a bright surface line and darken toward the bottom of a pool (SHADE in tuning.h).

namespace {
const uint8_t FIRE_PAL[6][3] = { { 255, 241, 184 }, { 255, 209, 102 }, { 244, 160, 58 }, { 224, 96, 42 }, { 168, 51, 31 }, { 90, 29, 20 } };
const uint8_t G_FIRE[6][3] = { { 255, 190, 90 }, { 255, 150, 50 }, { 230, 100, 30 }, { 170, 60, 20 }, { 90, 25, 10 }, { 30, 8, 4 } };
const uint8_t BURN_RGB[3][3] = { { 255, 150, 50 }, { 230, 100, 30 }, { 170, 60, 20 } };
const uint8_t G_ICHOR[3] = { 34, 80, 6 }, G_ICHOR_DIM[3] = { 12, 30, 2 }, G_HOLY[3] = { 6, 16, 28 }, G_MIASMA[3] = { 26, 34, 4 };

// a cheap per-cell, per-tick random number for flicker (rendering never touches the simulation's random stream)
inline uint32_t flick(uint32_t i, uint32_t t) {
	uint32_t x = i * 0x9E3779B1u ^ (t * 0x85EBCA77u);
	x ^= x >> 15;
	x *= 0x2C1B3C6Du;
	x ^= x >> 12;
	return x;
}
inline void rgb_of(uint32_t c, float &r, float &g, float &b) {
	r = (float)((c >> 16) & 0xff);
	g = (float)((c >> 8) & 0xff);
	b = (float)(c & 0xff);
}
inline uint8_t clamp8(float v) {
	return v <= 0 ? 0 : (v >= 255 ? 255 : (uint8_t)v);
}
constexpr int MAXV_STREAK = 6;
inline int fire_idx(int l, float hv, uint32_t f) {
	int k = l > 22 ? 1 : l > 12 ? 2 : l > 6 ? 3 : l > 2 ? 4 : 5;
	if (hv > 40 && k > 0) {
		k--; // big hot fires burn whiter
	}
	if ((f & 1023) < 358) {
		k = std::min(5, k + 1);
	}
	return k;
}
} // namespace

void SandWorld::render_region(const Ref<Image> &image, int x0, int y0) {
	ERR_FAIL_COND(image.is_null());
	int iw = image->get_width(), ih = image->get_height();
	PackedByteArray buf;
	buf.resize((int64_t)iw * ih * 4);
	uint8_t *p = buf.ptrw();
	memset(p, 0, (size_t)iw * ih * 4);
	if (w == 0) {
		image->set_data(iw, ih, false, Image::FORMAT_RGBA8, buf);
		return;
	}
	const tune::ShadeTune &S = tune::SHADE;
	// per-column run counters for shading, primed from a few rows above the region
	std::vector<int16_t> sr(iw, 0), lr(iw, 0);
	const int look = 16;
	for (int xx = 0; xx < iw; xx++) {
		int wx = x0 + xx;
		if (wx < 0 || wx >= w) {
			continue;
		}
		for (int wy = std::max(0, y0 - look); wy < std::min(h, y0); wy++) {
			int i = idx(wx, wy), t = mat[i];
			Kind k = md(t).kind;
			if ((k == K_STATIC || k == K_POWDER) && !burn[i] && t != EMBER) {
				sr[xx]++;
				lr[xx] = 0;
			} else if (k == K_LIQUID) {
				lr[xx]++;
				sr[xx] = 0;
			} else {
				sr[xx] = lr[xx] = 0;
			}
		}
	}
	const uint32_t tk = (uint32_t)tick;
	for (int yy = 0; yy < ih; yy++) {
		int wy = y0 + yy;
		if (wy < 0 || wy >= h) {
			continue;
		}
		for (int xx = 0; xx < iw; xx++) {
			int wx = x0 + xx;
			if (wx < 0 || wx >= w) {
				continue;
			}
			uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
			int i = idx(wx, wy), t = mat[i];
			const MatDef &d = md(t);
			Kind k = d.kind;
			if (k == K_EMPTY) {
				sr[xx] = lr[xx] = 0;
				continue;
			}
			float r, g, b;
			rgb_of(d.colors[shade[i] >> 6], r, g, b);
			uint8_t alpha = 255;
			float f = 1.0f;
			if (k == K_GAS) {
				rgb_of(d.colors[0], r, g, b);
				alpha = clamp8(255.0f * d.gas_alpha * std::min(1.0f, life[i] / 40.0f));
				sr[xx] = lr[xx] = 0;
			} else if (k == K_FIRE) {
				const uint8_t *c = FIRE_PAL[fire_idx(life[i], heat[i], flick(i, tk))];
				r = c[0];
				g = c[1];
				b = c[2];
				sr[xx] = lr[xx] = 0;
			} else {
				if (burn[i] || t == EMBER) { // burning: the material shows through a flickering glow
					uint32_t fl = flick(i, tk);
					const uint8_t *c = BURN_RGB[fl % 3];
					float a = t == EMBER ? 0.55f + ((fl >> 8) & 255) / 255.0f * 0.35f : 0.35f + ((fl >> 8) & 255) / 255.0f * 0.4f;
					r = r * (1 - a) + c[0] * a;
					g = g * (1 - a) + c[1] * a;
					b = b * (1 - a) + c[2] * a;
				} else if (st_l[i]) { // a stain, coloured by its age
					const MatDef &sd = md(st_t[i]);
					int age = sd.st_ticks ? 63 - std::min(63, (int)(st_l[i] * 63 / sd.st_ticks)) : 63;
					const uint8_t *lut = sd.st_lut[age];
					float a = lut[3] / 255.0f * (st_i[i] / 255.0f);
					r = r * (1 - a) + lut[0] * a;
					g = g * (1 - a) + lut[1] * a;
					b = b * (1 - a) + lut[2] * a;
				} else if (mx_a[i]) { // two liquids mixed in one cell
					float r2, g2, b2, a = mx_a[i] / 255.0f;
					rgb_of(md(mx_t[i]).colors[shade[i] >> 6], r2, g2, b2);
					r = r * (1 - a) + r2 * a;
					g = g * (1 - a) + g2 * a;
					b = b * (1 - a) + b2 * a;
				}
				if (wear[i] > 0 && d.hardness > 0) { // worn by digging: pale and cracked
					float a = std::min(S.wear_max, wear[i] / d.hardness * 0.75f);
					r = r * (1 - a) + 205 * a;
					g = g * (1 - a) + 225 * a;
					b = b * (1 - a) + 190 * a;
				}
				// shading
				if ((k == K_STATIC || k == K_POWDER) && !burn[i] && t != EMBER) {
					int s = ++sr[xx];
					lr[xx] = 0;
					f = s == 1 ? S.rim : s == 2 ? S.rim2 : 1 - std::min(S.deepMax, (s - 2) * S.deep);
					if (wy < h - 1 && is_open_i(i + w)) {
						f *= S.under;
					} else if (s > 2 && ((wx > 0 && is_open_i(i - 1)) || (wx < w - 1 && is_open_i(i + 1)))) {
						f *= S.side;
					}
				} else if (k == K_LIQUID) {
					int s = ++lr[xx];
					sr[xx] = 0;
					f = (s == 1 && wy > 0 && is_open_i(i - w)) ? S.sheen : 1 - std::min(S.liqMax, (s - 1) * S.liqDeep);
				} else {
					sr[xx] = lr[xx] = 0;
				}
			}
			o[0] = clamp8(r * f);
			o[1] = clamp8(g * f);
			o[2] = clamp8(b * f);
			o[3] = alpha;
		}
	}
	// liquid falling through the air jumps several cells a tick; draw the gap it just crossed as a fading streak so a
	// pour reads as a stream rather than dashes
	for (int yy = 1; yy < ih; yy++) {
		int wy = y0 + yy;
		if (wy < 1 || wy >= h) {
			continue;
		}
		for (int xx = 0; xx < iw; xx++) {
			int wx = x0 + xx;
			if (wx < 0 || wx >= w) {
				continue;
			}
			int i = idx(wx, wy);
			if (plg[i] != 255 || fvy[i] < 1.5f || md(mat[i]).kind != K_LIQUID) {
				continue;
			}
			const uint8_t *src = p + ((size_t)yy * iw + xx) * 4;
			int len = std::min(MAXV_STREAK, (int)fvy[i] - 1);
			for (int k = 1; k <= len && yy - k >= 0; k++) {
				uint8_t *o = p + ((size_t)(yy - k) * iw + xx) * 4;
				if (o[3] == 255 || !is_open_i(i - k * w)) {
					break;
				}
				o[0] = src[0];
				o[1] = src[1];
				o[2] = src[2];
				o[3] = (uint8_t)(230 - k * 150 / (len + 1));
			}
		}
	}
	// airborne droplets and grains
	for (const Particle &pt : particles) {
		int xx = (int)pt.x - x0, yy = (int)pt.y - y0;
		if (xx < 0 || yy < 0 || xx >= iw || yy >= ih) {
			continue;
		}
		float r, g, b;
		rgb_of(md(pt.mat).colors[pt.shade >> 6], r, g, b);
		if (pt.mx_a) {
			float r2, g2, b2, a = pt.mx_a / 255.0f;
			rgb_of(md(pt.mx_t).colors[pt.shade >> 6], r2, g2, b2);
			r = r * (1 - a) + r2 * a;
			g = g * (1 - a) + g2 * a;
			b = b * (1 - a) + b2 * a;
		}
		uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
		o[0] = clamp8(r);
		o[1] = clamp8(g);
		o[2] = clamp8(b);
		o[3] = 255;
	}
	image->set_data(iw, ih, false, Image::FORMAT_RGBA8, buf);
}

void SandWorld::render_glow(const Ref<Image> &image, int x0, int y0) {
	ERR_FAIL_COND(image.is_null());
	int iw = image->get_width(), ih = image->get_height();
	PackedByteArray buf;
	buf.resize((int64_t)iw * ih * 4);
	uint8_t *p = buf.ptrw();
	memset(p, 0, (size_t)iw * ih * 4);
	const uint32_t tk = (uint32_t)tick;
	auto put_px = [&](uint8_t *o, int r, int g, int b) {
		o[0] = (uint8_t)std::min(255, r);
		o[1] = (uint8_t)std::min(255, g);
		o[2] = (uint8_t)std::min(255, b);
		o[3] = 255;
	};
	for (int yy = 0; yy < ih && w; yy++) {
		int wy = y0 + yy;
		if (wy < 0 || wy >= h) {
			continue;
		}
		for (int xx = 0; xx < iw; xx++) {
			int wx = x0 + xx;
			if (wx < 0 || wx >= w) {
				continue;
			}
			int i = idx(wx, wy), t = mat[i];
			const MatDef &d = md(t);
			uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
			if (t == EMPTY) {
				float hv = heat[i];
				if (hv > 4) {
					put_px(o, (int)std::min(90.0f, hv * 1.6f), (int)std::min(35.0f, hv * 0.5f), 0); // hot air glows faintly
				}
				continue;
			}
			if (d.kind == K_FIRE) {
				const uint8_t *c = G_FIRE[fire_idx(life[i], heat[i], flick(i, tk))];
				put_px(o, c[0], c[1], c[2]);
			} else if (t == MIASMA) {
				put_px(o, G_MIASMA[0], G_MIASMA[1], G_MIASMA[2]);
			} else if (burn[i] || t == EMBER) {
				const uint8_t *c = G_FIRE[t == EMBER ? 2 : 3];
				put_px(o, c[0], c[1], c[2]);
			} else if (st_l[i] && md(st_t[i]).st_glow) {
				const MatDef &sd = md(st_t[i]);
				int age = 63 - std::min(63, (int)(st_l[i] * 63 / std::max<int>(1, sd.st_ticks)));
				if (age < 24) {
					put_px(o, G_ICHOR_DIM[0], G_ICHOR_DIM[1], G_ICHOR_DIM[2]); // fresh ichor stains glow
				}
			} else if (t == ICHOR || (d.kind == K_LIQUID && mx_t[i] == ICHOR)) {
				const uint8_t *c = mx_a[i] ? G_ICHOR_DIM : G_ICHOR;
				put_px(o, c[0], c[1], c[2]);
			} else if (t == HOLY) {
				put_px(o, G_HOLY[0], G_HOLY[1], G_HOLY[2]);
			} else if (d.glow) {
				put_px(o, (d.glow >> 16) & 0xff, (d.glow >> 8) & 0xff, d.glow & 0xff);
			}
		}
	}
	for (const Particle &pt : particles) {
		int xx = (int)pt.x - x0, yy = (int)pt.y - y0;
		if (xx < 0 || yy < 0 || xx >= iw || yy >= ih) {
			continue;
		}
		uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
		if (pt.mat == ICHOR) {
			put_px(o, G_ICHOR[0], G_ICHOR[1], G_ICHOR[2]);
		} else if (pt.mat == HOLY) {
			put_px(o, G_HOLY[0], G_HOLY[1], G_HOLY[2]);
		} else if (pt.mat == EMBER) {
			put_px(o, G_FIRE[2][0], G_FIRE[2][1], G_FIRE[2][2]);
		}
	}
	image->set_data(iw, ih, false, Image::FORMAT_RGBA8, buf);
}

// ---------------------------------------------------------------- save and load

PackedByteArray SandWorld::get_cells() const {
	PackedByteArray out;
	out.resize((int64_t)mat.size());
	if (!mat.empty()) {
		memcpy(out.ptrw(), mat.data(), mat.size());
	}
	return out;
}

void SandWorld::set_cells(const PackedByteArray &cells) {
	ERR_FAIL_COND_MSG((size_t)cells.size() != mat.size(), "SandWorld.set_cells: size does not match width*height.");
	const uint8_t *src = cells.ptr();
	particles.clear();
	bodies.clear();
	collapse_seeds.clear();
	crush_events = Array();
	for (int i = 0; i < n; i++) {
		uint8_t sh = shade[i];
		put(i, src[i] < MAT_COUNT ? src[i] : EMPTY);
		shade[i] = sh;
		mov[i] = md(mat[i]).kind == K_POWDER ? 1 : 0;
		heat[i] = 0;
	}
	std::fill(hot.begin(), hot.end(), 0);
	std::fill(has_stain.begin(), has_stain.end(), 0);
	std::fill(active_next.begin(), active_next.end(), 1);
}

// ---------------------------------------------------------------- material info

String SandWorld::mat_name(int m) {
	init_materials();
	const char *n = mat_def(m).name;
	return n ? String(n) : String("Unknown");
}

int SandWorld::mat_kind(int m) {
	init_materials();
	return mat_def(m).kind;
}

float SandWorld::mat_hardness(int m) {
	init_materials();
	return mat_def(m).hardness;
}

// ---------------------------------------------------------------- bindings

#define BIND_MAT(name) ClassDB::bind_integer_constant(get_class_static(), StringName(), "M_" #name, unholy::name);
#define BIND_KIND(name) ClassDB::bind_integer_constant(get_class_static(), StringName(), #name, unholy::name);

void SandWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "width", "height", "seed"), &SandWorld::setup);
	ClassDB::bind_method(D_METHOD("get_width"), &SandWorld::get_width);
	ClassDB::bind_method(D_METHOD("get_height"), &SandWorld::get_height);
	ClassDB::bind_method(D_METHOD("get_tick"), &SandWorld::get_tick);
	ClassDB::bind_method(D_METHOD("step"), &SandWorld::step);
	ClassDB::bind_method(D_METHOD("wake_rect", "x", "y", "w", "h"), &SandWorld::wake_rect);
	ClassDB::bind_method(D_METHOD("active_chunk_count"), &SandWorld::active_chunk_count);

	ClassDB::bind_method(D_METHOD("get_mat", "x", "y"), &SandWorld::get_mat);
	ClassDB::bind_method(D_METHOD("set_mat", "x", "y", "mat"), &SandWorld::set_mat);
	ClassDB::bind_method(D_METHOD("fill_rect", "x", "y", "w", "h", "mat"), &SandWorld::fill_rect);
	ClassDB::bind_method(D_METHOD("paint_circle", "cx", "cy", "r", "mat", "only_empty"), &SandWorld::paint_circle, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("in_bounds", "x", "y"), &SandWorld::in_bounds);
	ClassDB::bind_method(D_METHOD("is_solid", "x", "y"), &SandWorld::is_solid);
	ClassDB::bind_method(D_METHOD("is_liquid", "x", "y"), &SandWorld::is_liquid);
	ClassDB::bind_method(D_METHOD("is_empty", "x", "y"), &SandWorld::is_empty);
	ClassDB::bind_method(D_METHOD("get_kind", "x", "y"), &SandWorld::get_kind);

	ClassDB::bind_method(D_METHOD("raycast", "from", "to", "stop_at_liquid"), &SandWorld::raycast, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("count_rect", "x", "y", "w", "h"), &SandWorld::count_rect);
	ClassDB::bind_method(D_METHOD("surface_y", "x", "from_y"), &SandWorld::surface_y, DEFVAL(0));

	ClassDB::bind_method(D_METHOD("dig", "cx", "cy", "r", "power"), &SandWorld::dig);
	ClassDB::bind_method(D_METHOD("spill", "x", "y", "mat", "count", "vx", "vy"), &SandWorld::spill);
	ClassDB::bind_method(D_METHOD("ignite", "x", "y", "r"), &SandWorld::ignite);
	ClassDB::bind_method(D_METHOD("explode", "cx", "cy", "r", "force"), &SandWorld::explode);
	ClassDB::bind_method(D_METHOD("take_crush_events"), &SandWorld::take_crush_events);
	ClassDB::bind_method(D_METHOD("get_heat", "x", "y"), &SandWorld::get_heat);
	ClassDB::bind_method(D_METHOD("add_heat", "cx", "cy", "r", "amount"), &SandWorld::add_heat);
	ClassDB::bind_method(D_METHOD("get_stain", "x", "y"), &SandWorld::get_stain);
	ClassDB::bind_method(D_METHOD("is_burning", "x", "y"), &SandWorld::is_burning);
	ClassDB::bind_method(D_METHOD("falling_chunk_count"), &SandWorld::falling_chunk_count);
	ClassDB::bind_method(D_METHOD("particle_count"), &SandWorld::particle_count);

	ClassDB::bind_method(D_METHOD("render_region", "image", "x0", "y0"), &SandWorld::render_region);
	ClassDB::bind_method(D_METHOD("render_glow", "image", "x0", "y0"), &SandWorld::render_glow);

	ClassDB::bind_method(D_METHOD("get_cells"), &SandWorld::get_cells);
	ClassDB::bind_method(D_METHOD("set_cells", "cells"), &SandWorld::set_cells);

	ClassDB::bind_static_method("SandWorld", D_METHOD("mat_name", "mat"), &SandWorld::mat_name);
	ClassDB::bind_static_method("SandWorld", D_METHOD("mat_kind", "mat"), &SandWorld::mat_kind);
	ClassDB::bind_static_method("SandWorld", D_METHOD("mat_hardness", "mat"), &SandWorld::mat_hardness);

	BIND_KIND(K_EMPTY);
	BIND_KIND(K_STATIC);
	BIND_KIND(K_POWDER);
	BIND_KIND(K_LIQUID);
	BIND_KIND(K_GAS);
	BIND_KIND(K_FIRE);

	BIND_MAT(EMPTY);
	BIND_MAT(STONE);
	BIND_MAT(DIRT);
	BIND_MAT(ASH);
	BIND_MAT(BONE);
	BIND_MAT(FLESH);
	BIND_MAT(WOOD);
	BIND_MAT(BLOOD);
	BIND_MAT(HOLY);
	BIND_MAT(ICHOR);
	BIND_MAT(TALLOW);
	BIND_MAT(FIRE);
	BIND_MAT(SMOKE);
	BIND_MAT(STEAM);
	BIND_MAT(MIASMA);
	BIND_MAT(MUD);
	BIND_MAT(EMBER);
	BIND_MAT(EARTH);
	BIND_MAT(BEDROCK);
	BIND_MAT(RUBBLE);
	BIND_MAT(BONEBIT);
	BIND_MAT(GRASS);
	BIND_MAT(LEAVES);
	BIND_MAT(PLANK);
	BIND_MAT(BRICK);
	BIND_MAT(SAND);
	BIND_MAT(SNOW);
	BIND_MAT(EMBALM);
	BIND_MAT(GIBS);
	BIND_MAT(CLAY);
}
