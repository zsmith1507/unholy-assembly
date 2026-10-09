#include "sand_world.h"
#include "tuning.h"

#include <godot_cpp/core/class_db.hpp>

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
	cw = (w + CHUNK - 1) / CHUNK;
	chh = (h + CHUNK - 1) / CHUNK;
	tick = 0;
	rng = seed ? (uint32_t)seed : 0x9e3779b9u;
	size_t n = (size_t)w * h;
	mat.assign(n, EMPTY);
	shade.resize(n);
	for (size_t i = 0; i < n; i++) {
		shade[i] = (uint8_t)(rnd_u() & 0xff);
	}
	life.assign(n, 0);
	wear.assign(n, 0.0f);
	stamp.assign(n, 0);
	active.assign((size_t)cw * chh, 1);
	active_next.assign((size_t)cw * chh, 1);
	particles.clear();
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

void SandWorld::put(int i, int m) {
	mat[i] = (uint8_t)m;
	shade[i] = (uint8_t)(rnd_u() & 0xff);
	wear[i] = 0.0f;
	const MatDef &d = mat_def(m);
	life[i] = d.life_max ? (uint16_t)(d.life_min + (rnd_u() % (uint32_t)(d.life_max - d.life_min + 1))) : 0;
	stamp[i] = (uint32_t)tick;
	wake_at(i % w, i / w);
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

// ---------------------------------------------------------------- simulation

bool SandWorld::can_displace(int m, int target) const {
	const MatDef &t = mat_def(target);
	if (t.kind == K_EMPTY || t.kind == K_GAS || t.kind == K_FIRE) {
		return true;
	}
	if (t.kind == K_LIQUID) {
		return mat_def(m).density > t.density;
	}
	return false;
}

void SandWorld::swap_cells(int a, int b) {
	std::swap(mat[a], mat[b]);
	std::swap(shade[a], shade[b]);
	std::swap(life[a], life[b]);
	std::swap(wear[a], wear[b]);
	stamp[a] = stamp[b] = (uint32_t)tick;
	wake_at(a % w, a / w);
	wake_at(b % w, b / w);
}

void SandWorld::update_powder(int x, int y, int i, bool lf) {
	if (y + 1 >= h) {
		return;
	}
	int below = i + w;
	if (can_displace(mat[i], mat[below])) {
		// sinking through liquid is slower than falling through air
		if (mat_def(mat[below]).kind == K_LIQUID && rnd() < 0.5f) {
			wake_at(x, y);
			return;
		}
		swap_cells(i, below);
		return;
	}
	// FRIC: a grain on a slope may come to rest; SLUMP: sluggish stuff (flesh, mud) only moves some ticks
	const MatDef &pd = mat_def(mat[i]);
	if (rnd() < pd.fric || rnd() > pd.slump) {
		if (rnd() < 0.5f) {
			wake_at(x, y); // stay awake a little so a resting grain can still be knocked loose
		}
		return;
	}
	int d1 = lf ? -1 : 1;
	for (int k = 0; k < 2; k++) {
		int d = k == 0 ? d1 : -d1;
		int nx = x + d;
		if (nx < 0 || nx >= w) {
			continue;
		}
		int side = i + d, diag = below + d;
		if (can_displace(mat[i], mat[diag]) && can_displace(mat[i], mat[side])) {
			swap_cells(i, diag);
			return;
		}
	}
}

void SandWorld::update_liquid(int x, int y, int i, bool lf) {
	const MatDef &d = mat_def(mat[i]);
	if (d.viscosity > 0 && rnd() < d.viscosity) {
		wake_at(x, y);
		return;
	}
	if (y + 1 < h) {
		int below = i + w;
		const MatDef &b = mat_def(mat[below]);
		// ABSORB: soil drinks liquid that sits on it (stone and bone hold it). Grave dirt soaked in blood or water turns to mud.
		if (b.absorb > 0 && rnd() < b.absorb) {
			if (mat[below] == DIRT && (mat[i] == BLOOD || mat[i] == HOLY) && rnd() < tune::SOIL.mud) {
				put(below, MUD);
			}
			put(i, EMPTY);
			return;
		}
		if (b.kind == K_EMPTY || b.kind == K_GAS || b.kind == K_FIRE) {
			swap_cells(i, below);
			return;
		}
		if (b.kind == K_LIQUID && d.density > b.density + 0.01f && rnd() < 0.3f) {
			swap_cells(i, below);
			return;
		}
		int d1 = lf ? -1 : 1;
		for (int k = 0; k < 2; k++) {
			int dir = k == 0 ? d1 : -d1;
			int nx = x + dir;
			if (nx < 0 || nx >= w) {
				continue;
			}
			Kind dk = mat_def(mat[below + dir]).kind;
			if (dk == K_EMPTY || dk == K_GAS) {
				swap_cells(i, below + dir);
				return;
			}
		}
	}
	// spread sideways up to `dispersion` cells
	int dir = lf ? -1 : 1;
	for (int k = 0; k < 2; k++, dir = -dir) {
		int best = -1;
		for (int s = 1; s <= d.dispersion; s++) {
			int nx = x + dir * s;
			if (nx < 0 || nx >= w) {
				break;
			}
			Kind nk = mat_def(mat[idx(nx, y)]).kind;
			if (nk != K_EMPTY && nk != K_GAS) {
				break;
			}
			best = idx(nx, y);
			// stop at a drop so liquid pours over ledges instead of skating across
			if (y + 1 < h && mat_def(mat[idx(nx, y + 1)]).kind == K_EMPTY) {
				break;
			}
		}
		if (best >= 0) {
			swap_cells(i, best);
			return;
		}
	}
}

void SandWorld::update_gas(int x, int y, int i, bool lf) {
	if (life[i] > 0) {
		life[i]--;
	}
	wake_at(x, y);
	if (life[i] == 0) {
		put(i, EMPTY);
		return;
	}
	int ny = y - 1;
	int dx = (int)(rnd_u() % 3) - 1;
	int nx = x + dx;
	if (ny >= 0 && nx >= 0 && nx < w) {
		int j = idx(nx, ny);
		if (mat_def(mat[j]).kind == K_EMPTY) {
			swap_cells(i, j);
			return;
		}
	}
	int sx = x + (lf ? -1 : 1);
	if (sx >= 0 && sx < w && mat_def(mat[idx(sx, y)]).kind == K_EMPTY && rnd() < 0.5f) {
		swap_cells(i, idx(sx, y));
	}
}

void SandWorld::catch_fire(int j, int m) {
	const MatDef &d = mat_def(m);
	put(j, FIRE);
	if (d.fuel1 > 0) {
		// FIRE block: fuel is how many ticks this material burns; timber and flesh smoulder long and leave embers
		life[j] = (uint16_t)(d.fuel0 + (rnd_u() % (uint32_t)(d.fuel1 - d.fuel0 + 1)));
		shade[j] = (uint8_t)((shade[j] & ~1u) | (d.fuel0 >= 200 ? 1u : 0u));
	} else {
		shade[j] &= ~1u;
	}
}

void SandWorld::update_fire(int x, int y, int i) {
	wake_at(x, y);
	// spread to flammable neighbours; water-like liquids put it out
	static const int nx4[8] = { -1, 1, 0, 0, -1, 1, -1, 1 };
	static const int ny4[8] = { 0, 0, -1, 1, -1, -1, 1, 1 };
	for (int k = 0; k < 8; k++) {
		int xx = x + nx4[k], yy = y + ny4[k];
		if (!in_bounds(xx, yy)) {
			continue;
		}
		int j = idx(xx, yy);
		int m = mat[j];
		const MatDef &d = mat_def(m);
		if (m == BLOOD || m == HOLY) {
			put(i, STEAM);
			return;
		}
		if (d.fueled && rnd() < tune::CATCH_SCALE / ((1.0f + d.ign) * (1.0f + d.ign))) {
			catch_fire(j, m);
		}
	}
	if (life[i] > 0) {
		life[i]--;
	}
	if (life[i] == 0) {
		float r = rnd();
		// long-burning fuel (timber, flesh) leaves embers behind; everything leaves some smoke and ash
		bool long_burn = shade[i] & 1;
		put(i, (long_burn && r < tune::EMBER_LEAVE) ? EMBER : (r < 0.35f ? SMOKE : (r < 0.42f ? ASH : EMPTY)));
		return;
	}
	int up = i - w;
	if (shade[i] & 1) {
		// burning fuel stays put and throws short flames into the air above it
		if (y > 0 && mat_def(mat[up]).kind == K_EMPTY && rnd() < tune::FUEL_FLAME) {
			put(up, FIRE);
			shade[up] &= ~1u;
			life[up] = (uint16_t)(10 + rnd_u() % 20);
		}
		return;
	}
	// loose flames lick upward
	if (y > 0 && rnd() < 0.3f && mat_def(mat[up]).kind == K_EMPTY) {
		swap_cells(i, up);
	}
}

void SandWorld::update_cell(int x, int y, bool lf) {
	int i = idx(x, y);
	if (stamp[i] == (uint32_t)tick) {
		return;
	}
	switch (mat_def(mat[i]).kind) {
		case K_POWDER:
			update_powder(x, y, i, lf);
			break;
		case K_LIQUID:
			update_liquid(x, y, i, lf);
			break;
		case K_GAS:
			update_gas(x, y, i, lf);
			break;
		case K_FIRE:
			update_fire(x, y, i);
			break;
		default:
			break;
	}
}

void SandWorld::step() {
	if (w == 0) {
		return;
	}
	tick++;
	active.swap(active_next);
	std::fill(active_next.begin(), active_next.end(), 0);
	bool lf = (tick & 1) != 0;
	for (int cy = chh - 1; cy >= 0; cy--) {
		for (int cx = 0; cx < cw; cx++) {
			if (!active[cy * cw + cx]) {
				continue;
			}
			int x0 = cx * CHUNK, x1 = std::min(w, x0 + CHUNK);
			int y0 = cy * CHUNK, y1 = std::min(h, y0 + CHUNK);
			for (int y = y1 - 1; y >= y0; y--) {
				if (lf) {
					for (int x = x0; x < x1; x++) {
						update_cell(x, y, (rnd_u() & 1) != 0);
					}
				} else {
					for (int x = x1 - 1; x >= x0; x--) {
						update_cell(x, y, (rnd_u() & 1) != 0);
					}
				}
			}
		}
	}
	step_particles();
}

// ---------------------------------------------------------------- particles (airborne grains)

void SandWorld::spill(int x, int y, int m, int count, float vx, float vy) {
	if (m <= 0 || m >= MAT_COUNT) {
		return;
	}
	for (int k = 0; k < count && particles.size() < 8000; k++) {
		Particle p;
		p.x = x + 0.5f;
		p.y = y + 0.5f;
		p.vx = vx + (rnd() - 0.5f) * 1.2f;
		p.vy = vy + (rnd() - 0.5f) * 1.2f;
		p.mat = (uint8_t)m;
		particles.push_back(p);
	}
}

void SandWorld::step_particles() {
	size_t keep = 0;
	for (size_t k = 0; k < particles.size(); k++) {
		Particle p = particles[k];
		p.vy += 0.25f;
		float steps = std::max(std::fabs(p.vx), std::fabs(p.vy));
		int n = std::max(1, (int)std::ceil(steps));
		float sx = p.vx / n, sy = p.vy / n;
		bool landed = false;
		int px = (int)p.x, py = (int)p.y;
		for (int s = 0; s < n; s++) {
			float nx = p.x + sx, ny = p.y + sy;
			int ix = (int)std::floor(nx), iy = (int)std::floor(ny);
			if (!in_bounds(ix, iy) || !is_empty(ix, iy)) {
				landed = true;
				break;
			}
			p.x = nx;
			p.y = ny;
			px = ix;
			py = iy;
		}
		if (landed) {
			if (in_bounds(px, py) && is_empty(px, py)) {
				put(idx(px, py), p.mat);
			}
			continue;
		}
		particles[keep++] = p;
	}
	particles.resize(keep);
}

// ---------------------------------------------------------------- spells and damage

Dictionary SandWorld::dig(int cx, int cy, int r, float power) {
	int removed[MAT_COUNT] = { 0 };
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
			const MatDef &d = mat_def(mat[i]);
			if (d.kind != K_STATIC && d.kind != K_POWDER) {
				continue;
			}
			if (d.hardness <= 0) {
				continue; // bedrock
			}
			float falloff = 1.0f - 0.6f * std::sqrt(d2) / (float)std::max(1, r);
			wear[i] += power * falloff;
			if (wear[i] >= d.hardness) {
				removed[mat[i]]++;
				put(i, EMPTY);
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
	for (int yy = y - r; yy <= y + r; yy++) {
		for (int xx = x - r; xx <= x + r; xx++) {
			if (!in_bounds(xx, yy)) {
				continue;
			}
			int i = idx(xx, yy);
			const MatDef &d = mat_def(mat[i]);
			if (d.fueled || d.kind == K_EMPTY) {
				if (d.fueled) {
					catch_fire(i, mat[i]);
					continue;
				}
				if (d.kind == K_EMPTY && rnd() > 0.3f) {
					continue;
				}
				put(i, FIRE);
			}
		}
	}
}

void SandWorld::explode(int cx, int cy, int r, float force) {
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
			int m = mat[i];
			const MatDef &d = mat_def(m);
			if (d.kind == K_EMPTY || d.hardness <= 0 && d.kind == K_STATIC) {
				continue;
			}
			if (d.hardness > force * (1.0f - dist / r) * 4.0f) {
				continue;
			}
			// some of it flies as debris, the rest is vaporised
			if (rnd() < 0.25f) {
				int debris = (d.kind == K_STATIC) ? ((m == BONE) ? BONEBIT : RUBBLE) : m;
				float k = force * 0.6f / std::max(1.0f, dist);
				spill(xx, yy, debris, 1, dx * k, dy * k - 1.5f);
			}
			put(i, (dist > r * 0.75f && rnd() < 0.3f) ? FIRE : (rnd() < 0.2f ? SMOKE : EMPTY));
		}
	}
}

Array SandWorld::take_crush_events() {
	Array out = crush_events;
	crush_events = Array();
	return out;
}

// ---------------------------------------------------------------- rendering

void SandWorld::render_region(const Ref<Image> &image, int x0, int y0) {
	ERR_FAIL_COND(image.is_null());
	int iw = image->get_width(), ih = image->get_height();
	PackedByteArray buf;
	buf.resize((int64_t)iw * ih * 4);
	uint8_t *p = buf.ptrw();
	for (int yy = 0; yy < ih; yy++) {
		int wy = y0 + yy;
		for (int xx = 0; xx < iw; xx++) {
			int wx = x0 + xx;
			uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
			if (!in_bounds(wx, wy)) {
				o[0] = o[1] = o[2] = 0;
				o[3] = 0;
				continue;
			}
			int i = idx(wx, wy);
			int m = mat[i];
			const MatDef &d = mat_def(m);
			if (d.kind == K_EMPTY) {
				o[0] = o[1] = o[2] = o[3] = 0;
				continue;
			}
			uint32_t c = d.colors[shade[i] >> 6];
			int r = (c >> 16) & 0xff, g = (c >> 8) & 0xff, b = c & 0xff;
			if (d.kind == K_FIRE) {
				// flicker
				uint32_t fc = d.colors[(shade[i] + tick) >> 6 & 3];
				r = (fc >> 16) & 0xff;
				g = (fc >> 8) & 0xff;
				b = fc & 0xff;
			}
			o[0] = (uint8_t)r;
			o[1] = (uint8_t)g;
			o[2] = (uint8_t)b;
			o[3] = d.kind == K_GAS ? (uint8_t)std::min(150, 40 + life[i]) : 255;
		}
	}
	// airborne grains
	for (const Particle &pt : particles) {
		int xx = (int)pt.x - x0, yy = (int)pt.y - y0;
		if (xx < 0 || yy < 0 || xx >= iw || yy >= ih) {
			continue;
		}
		uint32_t c = mat_def(pt.mat).colors[0];
		uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
		o[0] = (c >> 16) & 0xff;
		o[1] = (c >> 8) & 0xff;
		o[2] = c & 0xff;
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
	for (int yy = 0; yy < ih; yy++) {
		int wy = y0 + yy;
		for (int xx = 0; xx < iw; xx++) {
			int wx = x0 + xx;
			if (!in_bounds(wx, wy)) {
				continue;
			}
			int i = idx(wx, wy);
			const MatDef &d = mat_def(mat[i]);
			if (!d.glow) {
				continue;
			}
			uint32_t c = d.glow;
			uint8_t *o = p + ((size_t)yy * iw + xx) * 4;
			o[0] = (c >> 16) & 0xff;
			o[1] = (c >> 8) & 0xff;
			o[2] = c & 0xff;
			o[3] = 255;
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
	memcpy(mat.data(), cells.ptr(), mat.size());
	std::fill(wear.begin(), wear.end(), 0.0f);
	for (size_t i = 0; i < mat.size(); i++) {
		const MatDef &d = mat_def(mat[i]);
		life[i] = d.life_max ? d.life_max : 0;
	}
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
