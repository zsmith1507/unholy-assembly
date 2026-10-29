shader_type canvas_item;
render_mode blend_add, unshaded;
// Softens the sim's glow map (one texel per cell) into a necrotic bloom: the cell's own glow stays crisp,
// and a wide, banded halo spreads a few cells around it. Applied by game/art/install.gd to SimView's glow layer.

uniform float core = 1.0;       // the emissive cells themselves
uniform float halo = 1.6;       // strength of the spread
uniform float radius = 3.5;     // halo radius in cells
uniform float bands = 10.0;     // quantise the halo so it reads as pixel art (0 = smooth)

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	vec3 base = c.rgb * c.a;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	// 3 rings x 8 taps, gaussian-ish weights
	for (int r = 1; r <= 3; r++) {
		float rr = radius * float(r) / 3.0;
		float w = exp(-float(r * r) / 4.5);
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785398 + float(r) * 0.39;
			vec4 s = texture(TEXTURE, UV + vec2(cos(a), sin(a)) * rr * px);
			sum += s.rgb * s.a * w;
			wsum += w;
		}
	}
	vec3 h = sum / wsum * halo;
	if (bands > 0.0) {
		h = floor(h * bands + 0.5) / bands;
	}
	COLOR = vec4(base * core + h, 1.0);
}
