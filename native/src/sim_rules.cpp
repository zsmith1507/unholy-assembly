// The per-tick rules of the sand world: liquids, powders, gases, fire, heat, stains and airborne droplets.
// A port of prototypes/proving-ground.html (the functions keep the prototype's names in snake_case), run over the
// awake 64x64 chunks only. Tuning numbers live in tuning.h.
#include "sand_world.h"
#include "tuning.h"

#include <algorithm>
#include <cmath>

using namespace godot;
using namespace unholy;

namespace {
constexpr int MAXV = tune::LIQ.maxv;
constexpr float G_LIQ = tune::LIQ.gravity;

inline bool movable(int t) { return md(t).movable; }
inline float dens(int t) { return md(t).density; }
inline Kind kind(int t) { return md(t).kind; }
inline bool stainable(int t) {
	Kind k = md(t).kind;
	return k == K_STATIC || k == K_POWDER;
}
inline bool timber(int t) { return t == WOOD || t == PLANK; }
inline bool meat(int t) { return t == FLESH || t == GIBS; }
} // namespace

// ---------------------------------------------------------------- cell basics

void SandWorld::put(int i, int m) {
	mat[i] = (uint8_t)m;
	shade[i] = (uint8_t)(rnd_u() & 0xff);
	stamp[i] = (uint32_t)tick;
	vy[i] = 0;
	vx[i] = 0;
	if (m == EMPTY) { // a hole opens: the grains around it are disturbed
		int x0 = i % w;
		if (i >= w) {
			mov[i - w] = 1;
			if (x0 > 0) mov[i - w - 1] = 1;
			if (x0 < w - 1) mov[i - w + 1] = 1;
		}
		if (x0 > 0) mov[i - 1] = 1;
		if (x0 < w - 1) mov[i + 1] = 1;
	}
	fvx[i] = 0;
	fvy[i] = 0;
	plg[i] = 0;
	burn[i] = 0;
	wear[i] = 0;
	mov[i] = 1;
	body_of[i] = 0;
	st_t[i] = 0;
	st_l[i] = 0;
	st_i[i] = 0;
	mx_t[i] = 0;
	mx_a[i] = 0;
	const MatDef &d = md(m);
	life[i] = d.life_max ? (int16_t)(d.life_min + (int)(rnd() * (d.life_max - d.life_min))) : 0;
	if (m == EMBER) {
		burn[i] = (uint16_t)(150 + (int)(rnd() * 250)); // a fresh ember glows a few seconds, then goes to ash
	}
	wake_i(i);
}

void SandWorld::set_flame(int i, int lo, int hi) {
	put(i, FIRE);
	life[i] = (int16_t)(lo + (int)(rnd() * (hi - lo)));
}

void SandWorld::swap_cells(int a, int b) {
	std::swap(mat[a], mat[b]);
	std::swap(shade[a], shade[b]);
	std::swap(life[a], life[b]);
	std::swap(vy[a], vy[b]);
	std::swap(vx[a], vx[b]);
	std::swap(fvx[a], fvx[b]);
	std::swap(fvy[a], fvy[b]);
	std::swap(plg[a], plg[b]);
	std::swap(mov[a], mov[b]);
	std::swap(burn[a], burn[b]);
	std::swap(body_of[a], body_of[b]);
	std::swap(st_t[a], st_t[b]);
	std::swap(st_l[a], st_l[b]);
	std::swap(st_i[a], st_i[b]);
	std::swap(mx_t[a], mx_t[b]);
	std::swap(mx_a[a], mx_a[b]);
	std::swap(wear[a], wear[b]);
	stamp[a] = stamp[b] = (uint32_t)tick;
	wake_i(a);
	wake_i(b);
	if (st_t[a] || st_t[b]) {
		has_stain[chunk_of(a)] = 1;
		has_stain[chunk_of(b)] = 1;
	}
}

int SandWorld::rand_neighbor(int i, int x, int y) {
	int dx = (int)(rnd() * 3) - 1, dy = (int)(rnd() * 3) - 1;
	if (!dx && !dy) return -1;
	int nx = x + dx, ny = y + dy;
	if (nx < 0 || nx >= w || ny < 0 || ny >= h) return -1;
	return i + dy * w + dx;
}

// ---------------------------------------------------------------- liquid mixing
// Cells hold at most two liquids: the main one (mat) and a share of another (mx_t, mx_a).

static inline float share_of(uint8_t t, uint8_t mt, uint8_t ma, int A) {
	return t == A ? 1.0f - ma / 255.0f : (mt == A ? ma / 255.0f : 0.0f);
}

void SandWorld::mix_cells(int i, int j) {
	int A = mat[i], B = 0;
	int cs[3] = { mx_t[i], mat[j], mx_t[j] };
	for (int c : cs) {
		if (!c || c == A) continue;
		if (!B) B = c;
		else if (c != B) return; // three liquids: leave alone
	}
	if (!B) return;
	float r = mix_rate(A, B);
	if (r <= 0 || rnd() > r) return;
	float fi = share_of(mat[i], mx_t[i], mx_a[i], A), fj = share_of(mat[j], mx_t[j], mx_a[j], A);
	float diff = fj - fi;
	if (diff < 0.01f && diff > -0.01f) return;
	float k = 0.25f + rnd() * 0.25f;
	auto set_share = [&](int c, float f) {
		if (f >= 0.5f) {
			mat[c] = (uint8_t)A;
			mx_a[c] = (uint8_t)std::lround((1 - f) * 255);
			mx_t[c] = mx_a[c] ? (uint8_t)B : 0;
		} else {
			mat[c] = (uint8_t)B;
			mx_a[c] = (uint8_t)std::lround(f * 255);
			mx_t[c] = mx_a[c] ? (uint8_t)A : 0;
		}
	};
	set_share(i, fi + diff * k);
	set_share(j, fj - diff * k);
	wake_i(i);
	wake_i(j);
}

// ---------------------------------------------------------------- stains

bool SandWorld::put_stain(int j, int t, float s) {
	if (!stainable(mat[j])) return false;
	const MatDef &d = md(t);
	if (!d.stains) return false;
	if (d.st_cleans && st_t[j] && st_t[j] != t) { // holy water scrubs other stains away
		st_i[j] = st_i[j] > 70 ? st_i[j] - 70 : 0;
		if (!st_i[j]) {
			st_t[j] = 0;
			st_l[j] = 0;
		}
		return true;
	}
	if (st_t[j] && st_t[j] != t && s < st_i[j]) return true; // a weaker stain doesn't cover a stronger one
	bool same = st_t[j] == t;
	int si = (int)std::min(255.0f, std::max(0.0f, s));
	st_t[j] = (uint8_t)t;
	st_l[j] = d.st_ticks;
	st_i[j] = (uint8_t)std::min(255, same ? std::max((int)st_i[j], si) : si);
	has_stain[chunk_of(j)] = 1;
	return true;
}

void SandWorld::stain_at(int j, int t, float boost) {
	if (!stainable(mat[j])) return;
	if (rnd() > md(t).st_p * boost) return;
	int prev = st_t[j] == t ? st_i[j] : 0;
	put_stain(j, t, (float)std::min(255, std::max(110, prev + 22)));
}

// Liquid t hits surface cell `hit` moving along (dx, dy) at `speed`: the stain is driven into the material along the
// line of travel (deeper for faster hits and softer materials), and a hard hit sprays marks over the surface around it.
void SandWorld::splatter(int hit, int t, float dx, float dy, float speed) {
	const MatDef &sd = md(t);
	if (!sd.stains || hit < 0 || hit >= n || !stainable(mat[hit])) return;
	float len = std::sqrt(dx * dx + dy * dy);
	if (len <= 0) len = 1;
	float ux = dx / len, uy = dy / len;
	float s0 = std::min(255.0f, 120 + speed * 22);
	float reach_depth = speed * sd.st_pen;
	float fx = (hit % w) + 0.5f, fy = (hit / w) + 0.5f, budget = std::max(1.0f, reach_depth);
	int last = -1, k = 0;
	while (budget > 0 && k < 14) {
		int cx = (int)std::floor(fx), cy = (int)std::floor(fy);
		if (cx < 0 || cx >= w || cy < 0 || cy >= h) break;
		int q = cy * w + cx;
		if (q != last) {
			if (!put_stain(q, t, s0 * std::max(0.3f, 1 - k / (reach_depth + 1.5f)))) break;
			budget -= 1 / std::max(0.15f, md(mat[q]).soak); // hard materials use the push up fast
			last = q;
			k++;
		}
		fx += ux * 0.6f + (rnd() - 0.5f) * (0.35f + k * 0.12f); // wanders more the deeper it soaks
		fy += uy * 0.6f + (rnd() - 0.5f) * 0.35f;
		if (q == last && k > 1 && rnd() < md(mat[q]).soak * 0.35f) { // soft materials wick it sideways
			int side = q + (rnd() < 0.5f ? -1 : 1);
			if (side >= 0 && side < n) put_stain(side, t, s0 * 0.45f * std::max(0.3f, 1 - k / (reach_depth + 1.5f)));
		}
	}
	if (speed < 2) return;
	int hx = hit % w, hy = hit / w;
	int drops = (int)std::lround(speed * 1.8f * (sd.splash + 0.2f));
	float reach = 1.5f + speed * 1.1f * (sd.splash + 0.1f);
	for (int d = 0; d < drops; d++) {
		float r = rnd() * reach;
		int ox = (int)std::lround((rnd() * 2 - 1) * r + ux * r * 0.7f);
		int cx = hx + ox;
		if (cx < 0 || cx >= w) continue;
		for (int cy = std::max(0, hy - 3); cy <= std::min(h - 1, hy + 3); cy++) {
			int q = cy * w + cx;
			if (stainable(mat[q]) && cy > 0 && is_open_i(q - w)) {
				float fall = 1 - r / reach;
				put_stain(q, t, s0 * (0.35f + 0.45f * fall));
				if (rnd() < fall * md(mat[q]).soak && q + w < n) put_stain(q + w, t, s0 * 0.3f * fall);
				break;
			}
		}
	}
}

// Porous ground (ABSORB) drinks liquid t at cell j: it soaks in as a wet stain. A cell holds about SOIL.full worth;
// when it is full the liquid seeps a few cells deeper. Returns false when there is nowhere left for it to go.
bool SandWorld::soak_into(int j, int t) {
	const MatDef &ld = md(t);
	int target = -1;
	for (int k = 0, q = j; k <= tune::SOIL.depth && q < n; k++, q += w) {
		if (md(mat[q]).absorb <= 0) break;
		int wet = st_t[q] ? st_i[q] : 0;
		if (ld.st_cleans && st_t[q] && st_t[q] != t) { // holy water rinses a stain out as it soaks in
			target = q;
			break;
		}
		if (wet < tune::SOIL.full) {
			target = q;
			break;
		}
	}
	if (target < 0) return false;
	if (ld.st_cleans && st_t[target] && st_t[target] != t) {
		put_stain(target, t, 0);
	} else {
		int wet = st_t[target] == t ? st_i[target] : 0;
		st_t[target] = (uint8_t)t;
		st_i[target] = (uint8_t)std::min(255, wet + tune::SOIL.per_cell);
		st_l[target] = ld.st_ticks;
		has_stain[chunk_of(target)] = 1;
	}
	if (mat[target] == DIRT && (t == BLOOD || t == HOLY) && st_i[target] >= tune::SOIL.full && rnd() < tune::SOIL.mud) {
		uint8_t sh = shade[target], s_t = st_t[target], s_i = st_i[target];
		uint16_t s_l = st_l[target];
		put(target, MUD);
		shade[target] = sh;
		st_t[target] = s_t;
		st_i[target] = s_i;
		st_l[target] = s_l;
	}
	return true;
}

void SandWorld::decay_stains(int by) {
	for (int c = 0; c < cw * chh; c++) {
		if (!has_stain[c]) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK;
		int x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		bool any = false;
		for (int y = y0; y < y1; y++) {
			for (int i = y * w + x0, e = y * w + x1; i < e; i++) {
				if (!st_l[i]) continue;
				if (st_l[i] <= by) {
					st_l[i] = 0;
					st_t[i] = 0;
					st_i[i] = 0;
				} else {
					st_l[i] -= by;
					any = true;
				}
			}
		}
		has_stain[c] = any ? 1 : 0;
	}
}

// ---------------------------------------------------------------- splashes

bool SandWorld::launch(int i, float svx, float svy) {
	if ((int)particles.size() >= tune::PART.max) return false;
	Particle p;
	p.x = (i % w) + 0.5f;
	p.y = (i / w) + 0.5f;
	p.vx = svx;
	p.vy = svy;
	p.mat = mat[i];
	p.shade = shade[i];
	p.mx_t = mx_t[i];
	p.mx_a = mx_a[i];
	particles.push_back(p);
	put(i, EMPTY);
	return true;
}

// a blow of strength v breaks the surface at liquid cell b: surface cells beside it are thrown up and out
void SandWorld::crown(int b, int x, float v) {
	float s = md(mat[b]).splash;
	if (s <= 0 || v < tune::LIQ.crown_min) return;
	for (int side = -1; side <= 1; side += 2) {
		for (int r = 1; r <= 2; r++) {
			int nx = x + side * r;
			if (nx < 0 || nx >= w) break;
			int j = b + side * r;
			if (kind(mat[j]) != K_LIQUID || j < w || !is_open_i(j - w)) break;
			if (rnd() < 0.4f * s / r) launch(j, side * v * (0.12f + rnd() * 0.22f) * s, -v * (0.28f + rnd() * 0.32f) * s);
		}
	}
}

void SandWorld::step_particles() {
	size_t p = 0;
	while (p < particles.size()) {
		Particle &P = particles[p];
		float svx = P.vx, svy = P.vy + tune::PART.gravity;
		if (svy > MAXV) svy = MAXV;
		svx *= tune::PART.drag;
		int steps = std::max(1, (int)std::ceil(std::max(std::fabs(svx), std::fabs(svy))));
		float sx = svx / steps, sy = svy / steps;
		float x = P.x, y = P.y;
		bool landed = false, burned = false;
		int hit_cell = -1, last_open = -1;
		const MatDef &pd = md(P.mat);
		for (int s = 0; s < steps; s++) {
			float nx = x + sx, ny = y + sy;
			int cx = (int)std::floor(nx), cy = (int)std::floor(ny);
			if (cx < 0 || cx >= w) {
				svx = -svx * 0.4f;
				break;
			}
			if (cy < 0) {
				svy = 0;
				break;
			}
			if (cy >= h) {
				landed = true;
				break;
			}
			int q = cy * w + cx, tt = mat[q];
			// droplets pass through liquid that is itself still falling; they land on anything at rest
			if (tt != EMPTY && kind(tt) != K_GAS && kind(tt) != K_FIRE && !(kind(tt) == K_LIQUID && fvy[q] >= 0.5f && plg[q] >= 254)) {
				landed = true;
				hit_cell = q;
				break;
			}
			x = nx;
			y = ny;
			if (is_open_i(q)) last_open = q;
			if (pd.air_ign > 0 && heat[q] > pd.air_ign && is_open_i(q)) { // a droplet of fat in hot air goes up all at once
				set_flame(q, 8, 18);
				add_heat_i(q, 14);
				burned = true;
				break;
			}
		}
		P.x = x;
		P.y = y;
		P.vx = svx;
		P.vy = svy;
		if (burned) {
			particles[p] = particles.back();
			particles.pop_back();
			continue;
		}
		if (!landed) {
			p++;
			continue;
		}
		if (hit_cell >= 0 && pd.stains) splatter(hit_cell, P.mat, svx, svy, std::sqrt(svx * svx + svy * svy));
		// land where it is, or in the nearest open cell around it (rings outward)
		int x0 = std::min(w - 1, std::max(0, (int)std::floor(x))), y0 = std::min(h - 1, (int)std::floor(y));
		int j = is_open_i(y0 * w + x0) ? y0 * w + x0 : -1;
		for (int r = 1; r <= tune::PART.land_search && j < 0; r++) {
			int flip = rnd() < 0.5f ? 1 : -1;
			for (int dy = -r; dy <= r && j < 0; dy++) {
				int span = r - std::abs(dy);
				for (int s2 = 0; s2 < 2 && j < 0; s2++) {
					if (s2 && span == 0) break;
					int dx = (s2 ? -span : span) * flip;
					int cx = x0 + dx, cy = y0 + dy;
					if (cx < 0 || cx >= w || cy < 0 || cy >= h) continue;
					int q = cy * w + cx;
					if (is_open_i(q)) j = q;
				}
			}
		}
		if (j < 0 && last_open >= 0 && is_open_i(last_open)) j = last_open;
		if (j < 0) {
			for (int cy = y0; cy >= 0; cy--) {
				int q = cy * w + x0;
				if (is_open_i(q)) {
					j = q;
					break;
				}
				if (!movable(mat[q])) break;
			}
		}
		if (j >= 0) {
			uint8_t pm = P.mat, ps = P.shade, pmt = P.mx_t, pma = P.mx_a;
			put(j, pm);
			shade[j] = ps;
			mx_t[j] = pmt;
			mx_a[j] = pma;
			if (pd.kind == K_LIQUID) {
				fvx[j] = svx;
				fvy[j] = svy;
				plg[j] = 254; // a splash droplet: lands carrying its speed, but throws no new crown
				vx[j] = svx > 0.2f ? 1 : svx < -0.2f ? -1 : 0;
			} else {
				vy[j] = (int8_t)std::max(0, std::min(MAXV, (int)svy));
			}
		}
		particles[p] = particles.back();
		particles.pop_back();
	}
}

// ---------------------------------------------------------------- falling (powders and liquids share it)

// Accelerating fall. Sets fall_to (where the cell ended up) and impact (speed it hit something at, 0 if still falling).
int SandWorld::fall(int i, int x, int t) {
	float d = dens(t);
	bool liquid = kind(t) == K_LIQUID;
	int v = vy[i] + 1;
	if (v > MAXV) v = MAXV;
	int steps = v;
	float m = (float)v; // momentum left; liquids it plunges through eat it away
	int cur = i, cnt = 0;
	bool hit = false, entered = i >= w && kind(mat[i - w]) == K_LIQUID;
	while (cnt < steps) {
		int b = cur + w;
		if (b >= n) {
			hit = true;
			break;
		}
		int tt = mat[b];
		if (!movable(tt)) {
			hit = true;
			break;
		}
		if (kind(tt) == K_LIQUID) {
			if (!liquid && m < 2 && rnd() < tune::REACT.sink_slow) break; // powders sink slowly once slowed
			if (!entered) {
				entered = true;
				if (m >= 3) crown(b, x, m); // breaking the surface throws liquid up
			}
			// the liquid we plough into gets shoved aside (it swaps up behind us)
			fvx[b] += (rnd() < 0.5f ? -1 : 1) * m * (0.2f + rnd() * 0.3f);
			fvy[b] -= m * 0.1f;
			int tb = mat[b];
			if (tb != EMPTY && !(movable(tb) && kind(tb) != K_STATIC)) {
				hit = true;
				break;
			}
			swap_cells(cur, b);
			cur = b;
			cnt++;
			float drag = 0.8f + md(tt).viscosity * 5;
			if (dens(tt) > d) drag += (dens(tt) - d) * 8;
			if (!liquid) drag += 0.6f;
			m -= drag;
			if (m <= 0) {
				m = 0;
				break;
			}
			continue;
		}
		if (dens(tt) >= d) {
			if (vy[b] > 0) {
				m = std::min(m, (float)vy[b]);
				break;
			}
			hit = true;
			break;
		}
		swap_cells(cur, b);
		cur = b;
		cnt++;
	}
	fall_to = cur;
	impact = hit ? (int)std::lround(m) : 0;
	vy[cur] = (int8_t)(hit ? 0 : std::max(0, std::min(MAXV, (int)std::floor(m))));
	return cnt;
}

// ---------------------------------------------------------------- powders
// A grain is either moving or resting. A moving grain that lands slides off diagonally, and each tick has a chance
// (its FRIC) to come to rest. A resting grain stays put, even on a slope, until something disturbs it.

void SandWorld::wake_above(int i) {
	if (i < w) return;
	int x0 = i % w;
	if (rnd() < 0.7f) mov[i - w] = 1;
	if (x0 > 0 && rnd() < 0.45f) mov[i - w - 1] = 1;
	if (x0 < w - 1 && rnd() < 0.45f) mov[i - w + 1] = 1;
	wake_i(i - w);
}

void SandWorld::update_powder(int i, int x, int y, int t) {
	int moved = fall(i, x, t);
	if (moved > 0) { // it fell: whatever it was holding up is disturbed
		mov[fall_to] = 1;
		wake_above(i);
		if (impact) { // and where it lands, it knocks the grains beneath it loose
			int lx = fall_to % w, lb = fall_to + w;
			if (lb < n) {
				if (rnd() < 0.85f) mov[lb] = 1;
				if (lx > 0 && rnd() < 0.6f) mov[lb - 1] = 1;
				if (lx < w - 1 && rnd() < 0.6f) mov[lb + 1] = 1;
				wake_i(lb);
			}
		}
		return;
	}
	if (vy[i] > 0) { // slowed in a liquid this tick, still sinking
		wake_i(i);
		return;
	}
	if (fall_to >= n - w) {
		mov[i] = 0;
		return;
	}
	if (!mov[i]) return; // at rest: stays put until disturbed
	const MatDef &pd = md(t);
	float d = pd.density;
	int b = i + w;
	// REPOSE: perched over a drop deeper than its material allows, it can't stop; it has to slide on
	bool steep = false;
	for (int dx = -1; dx <= 1 && !steep; dx += 2) {
		int nx = x + dx;
		if (nx < 0 || nx >= w || !movable(mat[i + dx]) || dens(mat[i + dx]) >= d) continue;
		int k = 0;
		for (int q = b + dx; k <= pd.repose && q < n && movable(mat[q]) && dens(mat[q]) < d; q += w) k++;
		steep = k > pd.repose;
	}
	if (!steep && rnd() < pd.fric) { // friction brings it to rest
		mov[i] = 0;
		return;
	}
	if (pd.slump < 1.0f && rnd() > pd.slump) { // flesh slumps, mud is sluggish: they only move some ticks
		wake_i(i);
		return;
	}
	int s = rnd() < 0.5f ? -1 : 1;
	for (int k = 0; k < 2; k++) {
		int dx = k ? -s : s, nx = x + dx;
		if (nx < 0 || nx >= w) continue;
		int tb = mat[b + dx], ts = mat[i + dx];
		if (movable(tb) && dens(tb) < d && movable(ts) && dens(ts) < d) {
			swap_cells(i, b + dx);
			wake_above(i); // sliding away disturbs the grains it was propping up
			if (rnd() < 0.5f) mov[i + dx] = 1; // and jostles the one beside it
			return;
		}
	}
	if (pd.skid > 0 && rnd() < pd.skid) { // fine powders skid along before they stop
		int nx = x + s;
		if (nx >= 0 && nx < w) {
			int ts = mat[i + s];
			if (movable(ts) && dens(ts) < d) {
				swap_cells(i, i + s);
				wake_above(i);
				return;
			}
		}
	}
	mov[i] = 0; // nowhere to go: it settles
}

// ---------------------------------------------------------------- liquids

// Mixing, staining, soaking into soil and reactions with neighbours. Shared by awake liquids and the occasional pass
// over sleeping pools. Returns true if the cell is gone.
bool SandWorld::liquid_side_effects(int i, int x, int y, int &t) {
	int nj = rand_neighbor(i, x, y);
	if (nj >= 0) {
		if (kind(mat[nj]) == K_LIQUID) mix_cells(i, nj);
		else if (md(t).stains) stain_at(nj, t);
	}
	t = mat[i]; // mixing can flip which liquid dominates this cell
	// porous ground drinks liquid sitting on it or against it (stone and bone hold it)
	if (y < h - 1) {
		int b = i + w;
		float ab = md(mat[b]).absorb;
		if (ab > 0 && rnd() < ab && soak_into(b, t)) {
			put(i, EMPTY);
			return true;
		}
	}
	if (nj >= 0 && nj / w == y) {
		float ab = md(mat[nj]).absorb;
		if (ab > 0 && rnd() < ab * 0.5f && soak_into(nj, t)) {
			put(i, EMPTY);
			return true;
		}
	}
	if (t == BLOOD || t == ICHOR) {
		int j = rand_neighbor(i, x, y);
		if (j >= 0) {
			int tt = mat[j];
			if (t == BLOOD && tt == DIRT && rnd() < tune::REACT.blood_dirt_mud) {
				put(j, MUD);
				put(i, EMPTY);
				return true;
			}
			if (t == ICHOR) {
				if (meat(tt) && rnd() < tune::REACT.ichor_flesh_miasma) {
					put(j, MIASMA);
					if (rnd() < tune::REACT.ichor_spent) {
						put(i, EMPTY);
						return true;
					}
				} else if (tt == HOLY && rnd() < tune::REACT.ichor_holy) {
					put(j, STEAM);
					put(i, STEAM);
					return true;
				}
			}
		}
	}
	return false;
}

void SandWorld::update_liquid(int i, int x, int y, int t) {
	// deep inside a still pool of one liquid nothing can happen to a cell, so skip it (the pool's edges do the work)
	if (x > 0 && x < w - 1 && y > 0 && y < h - 1 && mat[i - 1] == t && mat[i + 1] == t && mat[i - w] == t && mat[i + w] == t &&
			!mx_a[i] && !plg[i] && fvy[i] == 0 && fvx[i] == 0) {
		return;
	}
	if (liquid_side_effects(i, x, y, t)) return;
	const MatDef &ld = md(t);
	float d = ld.density;

	// ---------- 1. falling (accelerates; plunges into resting pools when it arrives fast)
	if (y < h - 1) {
		float v = fvy[i] + G_LIQ;
		if (v < 1) v = 1;
		if (v > MAXV) v = MAXV;
		int steps = (int)v;
		int cur = i, cx = x, moved = 0;
		bool landed = false, waiting = false, spray = false;
		for (int s = 0; s < steps; s++) {
			int b = cur + w;
			if (b >= n) {
				landed = true;
				break;
			}
			int tb = mat[b];
			if (is_open_i(b)) { // free fall
				swap_cells(cur, b);
				cur = b;
				moved++;
				if (plg[cur] < 254) plg[cur] = 255;
				continue;
			}
			if (kind(tb) == K_LIQUID) {
				if (fvy[b] >= 0.5f) {
					// only really falling if it moved this tick (rows below update first); wait behind liquid still in the air
					if (stamp[b] == (uint32_t)tick && plg[b] >= 254) {
						if (v > fvy[b] + 1) v = fvy[b] + 1;
						waiting = true;
						break;
					}
					if (plg[b] == 0 || plg[b] >= 254) fvy[b] = 0;
				}
				// arriving from the air fast enough: break the surface, then drive down through the pool
				if (plg[cur] >= 254) {
					bool from_splash = plg[cur] == 254;
					spray = !from_splash;
					plg[cur] = 0;
					if (v >= 2) {
						if (!from_splash) crown(b, cx, v); // only fresh falls throw a crown, so splashes die out
						plg[cur] = (uint8_t)std::min(250L, std::lround(v * (from_splash ? 1.2f : 2.6f) * (1 - md(tb).viscosity) * std::min(1.4f, d / dens(tb))));
					}
				}
				if (plg[cur] > 0 && plg[cur] < 254) {
					plg[cur]--;
					plunge_through(cur, b, cx, v, spray);
					cur = b;
					moved++;
					v *= 1 - std::min(0.5f, 0.04f + md(tb).viscosity * 0.6f);
					if (v < 1) {
						v = 0;
						plg[cur] = 0;
						break;
					}
					continue;
				}
				if (dens(tb) < d) { // heavier sinks through lighter
					swap_cells(cur, b);
					cur = b;
					moved++;
					v = 1;
					break;
				}
				landed = true;
				break;
			}
			landed = true; // solid or powder
			break;
		}
		if (landed) {
			float hit = v;
			bool was_drop = plg[cur] == 254;
			if (hit >= 1.5f && ld.stains && cur + w < n) splatter(cur + w, t, fvx[cur] * 0.3f, hit, hit);
			fvy[cur] = 0;
			plg[cur] = 0;
			// a hard landing on something solid splats sideways, sometimes throwing a droplet
			if (hit >= tune::LIQ.splat_min && !was_drop && cur >= w && is_open_i(cur - w) && cur + w < n && kind(mat[cur + w]) != K_LIQUID) {
				float s = ld.splash;
				if (rnd() < s * 0.3f) {
					launch(cur, (rnd() < 0.5f ? -1 : 1) * (0.6f + rnd() * 1.4f) * s, -hit * (0.12f + rnd() * 0.15f) * s);
					return;
				}
				fvx[cur] = (rnd() < 0.5f ? -1 : 1) * hit * 0.6f; // extra spread on the next flow
			}
			if (moved) return;
		} else if (moved || waiting) {
			fvy[cur] = v;
			wake_i(cur);
			return;
		} else {
			fvy[i] = 0;
		}
	}

	// ---------- 2. resting: Noita-style flow, every cell, every tick
	if (ld.viscosity > 0 && rnd() < ld.viscosity) { // thick liquids spread sluggishly
		// stay awake only while it still has somewhere to go, so a settled pool of ichor can sleep
		bool room = (y < h - 1 && movable(mat[i + w]) && dens(mat[i + w]) < d) || (x > 0 && movable(mat[i - 1]) && dens(mat[i - 1]) < d) ||
				(x < w - 1 && movable(mat[i + 1]) && dens(mat[i + 1]) < d);
		if (room) wake_i(i);
		return;
	}
	if (y < h - 1) { // slip diagonally down (into open air, or through a lighter liquid)
		int b = i + w, s = vx[i] ? vx[i] : (rnd() < 0.5f ? -1 : 1);
		for (int k = 0; k < 2; k++) {
			int dx = k ? -s : s, nx = x + dx;
			if (nx < 0 || nx >= w) continue;
			int tb = mat[b + dx], ts = mat[i + dx];
			if (movable(tb) && dens(tb) < d && movable(ts) && dens(ts) < d) {
				swap_cells(i, b + dx);
				vx[b + dx] = (int8_t)dx;
				return;
			}
		}
	}
	// spread sideways; a fresh splat or landing droplet carries extra reach
	int boost = 0;
	if (fvx[i] != 0) {
		boost = (int)std::lround(std::fabs(fvx[i]));
		if (!vx[i]) vx[i] = fvx[i] > 0 ? 1 : -1;
		fvx[i] = 0;
	}
	int dir = vx[i] ? vx[i] : (rnd() < 0.5f ? -1 : 1);
	if (rnd() < 0.02f) dir = -dir;
	int dist = ld.dispersion + boost;
	if (flow(i, x, dir, dist, d) < 0) {
		dir = -dir;
		if (flow(i, x, dir, dist, d) < 0) vx[i] = (int8_t)dir;
	}
}

// A plunging cell at `cur` drives into liquid cell `b` below it. The liquid it displaces gets shoved out of the way:
// thrown up out of the surface if it's near the top, otherwise pushed aside or up behind.
void SandWorld::plunge_through(int cur, int b, int x, float v, bool spray) {
	float s = md(mat[b]).splash;
	bool near_top = cur >= w && is_open_i(cur - w);
	if (spray && near_top && rnd() < 0.55f * s) {
		int side = rnd() < 0.5f ? -1 : 1;
		float lvx = side * (0.4f + rnd() * 1.2f) * v * 0.25f, lvy = -v * (0.25f + rnd() * 0.3f) * s;
		if (launch(b, lvx, lvy)) {
			swap_cells(cur, b);
			return;
		}
	}
	int side = rnd() < 0.5f ? -1 : 1;
	for (int k = 0; k < 2; k++) { // shove it sideways if there's room beside it
		int dx = k ? -side : side, nx = x + dx;
		if (nx < 0 || nx >= w) continue;
		int q = b + dx;
		if (is_open_i(q)) {
			swap_cells(b, q);
			vx[q] = (int8_t)dx;
			fvx[q] = dx * v * 0.5f;
			swap_cells(cur, b);
			return;
		}
	}
	if (near_top) { // what it pushes out spills onto the surface beside the hole, never stacking up in the hole
		for (int r = 1; r <= 4; r++) {
			for (int k = 0; k < 2; k++) {
				int dx = (k ? -side : side) * r, nx = x + dx;
				if (nx < 0 || nx >= w) continue;
				int q = cur + dx;
				if (is_open_i(q)) {
					swap_cells(b, q);
					vx[q] = dx > 0 ? 1 : -1;
					fvx[q] = (dx > 0 ? 1 : -1) * (2 + v * 0.4f);
					swap_cells(cur, b);
					return;
				}
			}
		}
	}
	swap_cells(cur, b);
	vx[cur] = (int8_t)side;
	fvx[cur] = side * v * 0.4f; // the displaced cell (now above us) carries a sideways push
}

// Move cell i up to `dist` cells sideways through open space. Stops at the first lighter liquid (displacing it) and
// at a ledge (so it pours over). Returns the new index, or -1 if it couldn't move.
int SandWorld::flow(int i, int x, int dir, int dist, float d) {
	int last = -1;
	for (int k = 1; k <= dist; k++) {
		int nx = x + dir * k;
		if (nx < 0 || nx >= w) break;
		int j = i + dir * k, tt = mat[j];
		if (!movable(tt) || dens(tt) >= d) break;
		last = j;
		if (kind(tt) == K_LIQUID) break;
		if (j + w < n && movable(mat[j + w]) && dens(mat[j + w]) < d) break;
	}
	if (last < 0) return -1;
	swap_cells(i, last);
	vx[last] = (int8_t)dir;
	return last;
}

// ---------------------------------------------------------------- gases

void SandWorld::update_gas(int i, int x, int y, int t) {
	wake_i(i);
	if (--life[i] <= 0) {
		put(i, (t == STEAM && rnd() < tune::REACT.steam_condense) ? HOLY : EMPTY);
		return;
	}
	const MatDef &gd = md(t);
	if (rnd() > gd.rise) return;
	float d = gd.density;
	int dx = (int)(rnd() * 3) - 1, nx = x + dx;
	if (y > 0 && nx >= 0 && nx < w) {
		int j = i - w + dx, tt = mat[j];
		if (tt == EMPTY || ((kind(tt) == K_GAS || kind(tt) == K_LIQUID) && dens(tt) > d)) {
			swap_cells(i, j);
			return;
		}
	}
	int sx = x + (rnd() < 0.5f ? -1 : 1);
	if (sx >= 0 && sx < w && mat[i - x + sx] == EMPTY) swap_cells(i, i - x + sx);
}

// ---------------------------------------------------------------- fire

void SandWorld::update_fire(int i, int x, int y) {
	wake_i(i);
	add_heat_i(i, tune::BURN.flame_heat); // flames heat the air they're in
	int j = rand_neighbor(i, x, y);
	if (j >= 0) { // doused by liquid
		int tt = mat[j];
		if (tt == HOLY) {
			if (rnd() < 0.3f) put(j, STEAM);
			put(i, STEAM);
			heat[i] *= 0.5f;
			return;
		}
		if (tt == BLOOD || tt == ICHOR) {
			put(i, SMOKE);
			heat[i] *= 0.6f;
			return;
		}
	}
	if (--life[i] <= 0) {
		put(i, rnd() < 0.3f ? SMOKE : EMPTY);
		return;
	}
	if (y > 0 && rnd() < tune::BURN.flame_rise) { // rise and lick about
		int dx = (int)(rnd() * 3) - 1, nx = x + dx;
		if (nx >= 0 && nx < w) {
			int k = i - w + dx, tt = mat[k];
			if (tt == EMPTY || kind(tt) == K_GAS) swap_cells(i, k);
		}
	}
}

// throw a flame into open air next to a burning cell, preferring straight up; hotter fires throw taller flames
void SandWorld::emit_flame(int i, int x, int y, bool big) {
	float hh = heat[i];
	int opts[5] = { i - w, i - w - 1, i - w + 1, i - 1, i + 1 };
	int start = (int)(rnd() * 3);
	for (int k = 0; k < 5; k++) {
		int q = k < 3 ? opts[(start + k) % 3] : opts[k];
		if (q < 0 || q >= n || std::abs(q % w - x) > 1) continue;
		if (mat[q] == EMPTY || kind(mat[q]) == K_GAS) {
			float extra = std::min(26.0f, hh * 0.5f) + (big ? 10 : 0);
			set_flame(q, (int)(6 + extra * 0.5f), (int)(14 + extra));
			return;
		}
	}
}

bool SandWorld::has_air(int i) const {
	int x = i % w;
	return (i >= w && is_open_i(i - w)) || (i < n - w && is_open_i(i + w)) || (x > 0 && is_open_i(i - 1)) || (x < w - 1 && is_open_i(i + 1));
}

// Solids and powders need to touch open air to burn; a flammable liquid can burn burn_depth layers below the surface.
bool SandWorld::air_reach(int i, int t) const {
	if (has_air(i)) return true;
	int depth = md(t).burn_depth;
	if (depth <= 1 || kind(t) != K_LIQUID) return false;
	for (int k = i - w, c = 1; k >= 0 && c <= depth; k -= w, c++) {
		if (is_open_i(k)) return true;
		if (mat[k] != t) return false;
	}
	return false;
}

// fat or spirit off the ground (falling, pouring, a droplet that just landed) burns all at once
bool SandWorld::airborne(int i, int t) const {
	return md(t).air_ign > 0 && (fvy[i] >= 0.5f || (i < n - w && is_open_i(i + w)));
}

void SandWorld::start_burn(int j) {
	int t = mat[j];
	const MatDef &d = md(t);
	if (!d.fueled || burn[j]) return;
	burn[j] = (uint16_t)(d.fuel0 + (int)(rnd() * (d.fuel1 - d.fuel0)));
	wake_i(j);
}

// A burning cell keeps its material (wood stays wood) while its fuel runs down. Returns true if it became something else.
bool SandWorld::update_burning(int i, int x, int y, int t) {
	wake_i(i);
	const tune::BurnTune &B = tune::BURN;
	for (int k = 0; k < 2; k++) { // quenched by holy water or blood touching it
		int j = rand_neighbor(i, x, y);
		if (j < 0) continue;
		if (kind(t) == K_LIQUID && j > i + 1) continue; // burning fat floats: liquid under it doesn't put it out
		int tt = mat[j];
		if ((tt == HOLY || tt == BLOOD) && rnd() < B.quench) {
			burn[i] = 0;
			heat[i] *= 0.3f;
			if (tt == HOLY && rnd() < 0.4f) put(j, STEAM);
			return false;
		}
	}
	if (!air_reach(i, t)) { // fire needs air: fat too deep in its pool goes out, wood smoulders without burning down
		if (kind(t) == K_LIQUID) burn[i] = 0;
		return false;
	}
	const MatDef &d = md(t);
	bool air = airborne(i, t);
	int rate = air ? (int)d.air_burn : 1;
	float bh = d.bheat * (air ? 3 : 1); // a burning cell heats itself and everything touching it
	add_heat_i(i, bh);
	if (y > 0) add_heat_i(i - w, bh * 0.7f);
	if (x > 0) add_heat_i(i - 1, bh * 0.45f);
	if (x < w - 1) add_heat_i(i + 1, bh * 0.45f);
	if (y < h - 1) add_heat_i(i + w, bh * (kind(t) == K_LIQUID ? 0.9f : 0.3f));
	burn[i] = burn[i] > rate ? burn[i] - rate : 0;
	if (rnd() < d.flamep * (air ? 4 : 1) * (1 + heat[i] / 30)) emit_flame(i, x, y, air);
	if (y > 0 && rnd() < B.smoke && mat[i - w] == EMPTY) put(i - w, SMOKE);

	if (timber(t)) {
		// pieces break away as it burns: undersides drop off, and anything barely attached falls
		int attached = 0;
		if (y > 0 && mat[i - w] == t) attached++;
		if (y < h - 1 && mat[i + w] == t) attached++;
		if (x > 0 && mat[i - 1] == t) attached++;
		if (x < w - 1 && mat[i + 1] == t) attached++;
		float loose = (y < h - 1 && is_open_i(i + w)) ? (attached <= 1 ? B.timber_drop_loose : B.timber_drop) : 0;
		if (loose > 0 && rnd() < loose) {
			mat[i] = EMBER;
			burn[i] = std::min<uint16_t>(burn[i], (uint16_t)(120 + (int)(rnd() * 200)));
			stamp[i] = (uint32_t)tick;
			seed_collapse(i);
			return true;
		}
		if (y > 0 && rnd() < B.ember_pop && mat[i - w] == EMPTY) { // an ember pops out of the fire and arcs away
			put(i - w, EMBER);
			if (!launch(i - w, (rnd() * 2 - 1) * 1.2f, -(0.8f + rnd() * 1.6f))) put(i - w, EMPTY);
		}
	}
	if (meat(t) && rnd() < B.flesh_drip) { // burning flesh renders down: fat drips out of it
		int ks[3] = { i + w, i - 1, i + 1 };
		for (int k : ks) {
			if (k >= 0 && k < n && mat[k] == EMPTY && std::abs(k % w - x) <= 1) {
				put(k, TALLOW);
				break;
			}
		}
	}
	if (burn[i] == 0) {
		float r = rnd();
		bool was_static = kind(t) == K_STATIC;
		if (timber(t)) {
			if (r < B.timber_ember) {
				mat[i] = EMBER;
				burn[i] = (uint16_t)(200 + (int)(rnd() * 280));
				stamp[i] = (uint32_t)tick;
			} else {
				put(i, r < B.timber_ember + B.timber_ash ? ASH : (r < B.timber_ember + B.timber_ash + B.timber_smoke ? SMOKE : EMPTY));
			}
		} else if (meat(t)) {
			put(i, r < B.flesh_ash ? ASH : (r < B.flesh_ash + B.flesh_smoke ? SMOKE : EMPTY));
		} else if (t == EMBER) {
			put(i, r < B.ember_ash ? ASH : EMPTY);
		} else {
			put(i, r < B.other_smoke ? SMOKE : EMPTY);
		}
		if (was_static) seed_collapse(i);
		return true;
	}
	return false;
}

// ---------------------------------------------------------------- heat
// Heat soaks into whatever is there, spreads to neighbours (mostly upward: hot air rises), and cools off. Only chunks
// with heat in them (and their neighbours) are processed.

float SandWorld::air_heat(int i) const {
	int x = i % w;
	float m = 0;
	if (i >= w && is_open_i(i - w) && heat[i - w] > m) m = heat[i - w];
	if (i < n - w && is_open_i(i + w) && heat[i + w] > m) m = heat[i + w];
	if (x > 0 && is_open_i(i - 1) && heat[i - 1] > m) m = heat[i - 1];
	if (x < w - 1 && is_open_i(i + 1) && heat[i + 1] > m) m = heat[i + 1];
	return m;
}

void SandWorld::heat_step() {
	const int nc = cw * chh;
	bool any = false;
	std::fill(zone.begin(), zone.end(), 0);
	for (int c = 0; c < nc; c++) {
		if (!hot[c]) continue;
		any = true;
		int cx = c % cw, cy = c / cw;
		for (int oy = -1; oy <= 1; oy++) {
			for (int ox = -1; ox <= 1; ox++) {
				int nx = cx + ox, ny = cy + oy;
				if (nx >= 0 && ny >= 0 && nx < cw && ny < chh) zone[ny * cw + nx] = 1;
			}
		}
	}
	if (!any) return;
	const tune::HeatTune &HT = tune::HEAT;
	for (int c = 0; c < nc; c++) {
		if (!zone[c]) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK, x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		for (int y = y0; y < y1; y++) std::fill(heat2.begin() + y * w + x0, heat2.begin() + y * w + x1, 0.0f);
	}
	for (int c = 0; c < nc; c++) {
		if (!hot[c]) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK, x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		for (int y = y0; y < y1; y++) {
			for (int x = x0; x < x1; x++) {
				int i = y * w + x;
				float hv = heat[i];
				if (hv < 0.02f) continue;
				const MatDef &d = md(mat[i]);
				float out = hv * d.spread;
				heat2[i] += hv - out - hv * d.cool;
				if (y > 0) heat2[i - w] += out * HT.up * md(mat[i - w]).cond;
				if (x > 0) heat2[i - 1] += out * HT.side * md(mat[i - 1]).cond;
				if (x < w - 1) heat2[i + 1] += out * HT.side * md(mat[i + 1]).cond;
				if (y < h - 1) heat2[i + w] += out * HT.down * md(mat[i + w]).cond;
			}
		}
	}
	for (int c = 0; c < nc; c++) {
		if (!zone[c]) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK, x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		bool warm = false;
		for (int y = y0; y < y1; y++) {
			for (int i = y * w + x0, e = y * w + x1; i < e; i++) {
				float hv = heat2[i];
				if (hv < 0.02f) hv = 0;
				else warm = true;
				heat[i] = hv;
			}
		}
		hot[c] = warm ? 1 : 0;
	}
	// let heat do its work
	for (int c = 0; c < nc; c++) {
		if (!zone[c]) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK, x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		for (int y = y0; y < y1; y++) {
			for (int i = y * w + x0, e = y * w + x1; i < e; i++) {
				int t = mat[i];
				const MatDef &d = md(t);
				float hv = heat[i];
				if (d.fueled) {
					if (burn[i] || t == EMBER) continue;
					float ign = airborne(i, t) ? d.air_ign : d.ign;
					float e2 = std::max(hv, air_heat(i) * 0.8f); // a surface catches from the hot air touching it too
					if (e2 > ign && ign > 0 && air_reach(i, t) && rnd() < std::min(0.25f, (e2 - ign) / ign * 0.08f)) start_burn(i);
				} else if (hv < 1) {
					continue;
				} else if (t == MIASMA) {
					if (hv > HT.miasma_flash) { // gas flashes; the burst sets off its neighbours
						set_flame(i, 5, 12);
						add_heat_i(i, 22);
					}
				} else if (t == ICHOR) {
					if (hv > HT.ichor_boil && rnd() < 0.02f) put(i, MIASMA);
				} else if (t == HOLY) {
					if (hv > HT.holy_boil && rnd() < 0.05f) {
						put(i, STEAM);
						heat[i] -= 8;
					}
				} else if (t == SNOW) {
					if (hv > HT.snow_melt && rnd() < 0.05f) {
						put(i, STEAM);
						heat[i] -= 4;
					}
				}
			}
		}
	}
}

// ---------------------------------------------------------------- the tick

void SandWorld::update_cell(int i, int x, int y) {
	int t = mat[i];
	if (burn[i] && update_burning(i, x, y, t)) return;
	switch (md(t).kind) {
		case K_POWDER:
			update_powder(i, x, y, t);
			break;
		case K_LIQUID:
			update_liquid(i, x, y, t);
			break;
		case K_GAS:
			update_gas(i, x, y, t);
			break;
		case K_FIRE:
			update_fire(i, x, y);
			break;
		default:
			break;
	}
}

// Pools in sleeping chunks still soak into soil, stain what they touch and mix, every SOIL.sleeping_every ticks.
void SandWorld::sleeping_liquids() {
	const int every = std::max(1, tune::SOIL.sleeping_every);
	for (int c = 0; c < cw * chh; c++) {
		if (active[c] || !has_liquid[c] || (tick + c) % every != 0) continue;
		int x0 = (c % cw) * CHUNK, y0 = (c / cw) * CHUNK, x1 = std::min(w, x0 + CHUNK), y1 = std::min(h, y0 + CHUNK);
		bool liq = false;
		for (int y = y0; y < y1; y++) {
			for (int x = x0; x < x1; x++) {
				int i = y * w + x, t = mat[i];
				if (md(t).kind != K_LIQUID) continue;
				liq = true;
				if (stamp[i] == (uint32_t)tick) continue;
				liquid_side_effects(i, x, y, t);
			}
		}
		has_liquid[c] = liq ? 1 : 0;
	}
}

void SandWorld::step() {
	if (w == 0) return;
	tick++;
	active.swap(active_next);
	std::fill(active_next.begin(), active_next.end(), 0);
	const bool ltr = (tick & 1) != 0;
	std::vector<int> row_chunks;
	row_chunks.reserve(cw);
	for (int cy = chh - 1; cy >= 0; cy--) {
		row_chunks.clear();
		for (int k = 0; k < cw; k++) {
			int cx = ltr ? k : cw - 1 - k;
			if (active[cy * cw + cx]) {
				row_chunks.push_back(cx);
				has_liquid[cy * cw + cx] = 0;
			}
		}
		if (row_chunks.empty()) continue;
		int y0 = cy * CHUNK, y1 = std::min(h, y0 + CHUNK);
		for (int y = y1 - 1; y >= y0; y--) {
			for (int cx : row_chunks) {
				int x0 = cx * CHUNK, x1 = std::min(w, x0 + CHUNK);
				uint8_t &liq = has_liquid[cy * cw + cx];
				for (int k = x0; k < x1; k++) {
					int x = ltr ? k : x1 - 1 - (k - x0);
					int i = y * w + x;
					int t = mat[i];
					if (t == EMPTY) continue;
					Kind kd = md(t).kind;
					if (kd == K_STATIC && !burn[i]) continue;
					if (kd == K_LIQUID) liq = 1;
					if (stamp[i] == (uint32_t)tick) continue;
					update_cell(i, x, y);
				}
			}
		}
	}
	sleeping_liquids();
	step_particles();
	step_bodies();
	if (tick % tune::COLLAPSE.every == 0) process_collapse();
	heat_step();
	if (tick % 8 == 0) decay_stains(8);
}
