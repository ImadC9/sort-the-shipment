shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Toy container (2.0). The mesh carries baked shading in its vertex colours:
//   COLOR.r = ambient occlusion x paint brightness
//   COLOR.g = frame mask (the frame turns gold on bonus cargo)
//   COLOR.b = bare-metal / buckle mask
// The colour symbol is stamped on the roof and on the door end from a 3x3
// atlas (R = fill, G = soft shadow), placed from the local position.

uniform vec4 tint : source_color = vec4(1.0);
uniform float highlight = 0.0;
uniform sampler2D symbol_tex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform int symbol = -1;
uniform vec3 symbol_col : source_color = vec3(1.0);
uniform float symbol_shadow = 0.34;
uniform vec3 strap_col : source_color = vec3(0.45, 0.33, 0.24);
uniform float tarp = 0.0;
instance uniform float end_symbol_alpha = 1.0;
instance uniform float gold = 0.0;

varying vec3 lp;
varying vec3 ln;

vec2 symbol_cover(vec2 q) {
	if (symbol < 0 || q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) {
		return vec2(0.0);
	}
	vec2 cell = vec2(float(symbol % 3), float(symbol / 3));
	// stay a texel inside the cell so neighbours never bleed in
	q = clamp(q, vec2(0.01), vec2(0.99));
	return texture(symbol_tex, (cell + q) / 3.0).rg;
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 paint = tint.rgb;
	vec3 gold_col = vec3(1.0, 0.80, 0.24);
	vec3 frame = mix(paint, gold_col * 1.22, gold);
	vec3 base = mix(paint, frame, COLOR.g);
	if (tarp > 0.5) {
		base = mix(paint, strap_col * 1.6, COLOR.g);
		base = mix(base, vec3(0.78, 0.74, 0.66) * 1.5, COLOR.b);
	} else {
		base = mix(base, mix(vec3(0.80, 0.84, 0.88), gold_col, gold) * 1.5, COLOR.b);
	}
	vec3 c = base * COLOR.r;
	// a gentle top-to-bottom gradient gives each box weight
	c *= mix(0.90, 1.03, smoothstep(0.0, 0.8, lp.y));
	// symbols: roof (read from above) and the door end (faces the camera)
	vec2 sc = vec2(0.0);
	if (ln.y > 0.6 && lp.y > 0.70) {
		sc = symbol_cover(vec2(0.5 - lp.x / 0.84, 0.5 - lp.z / 0.84));
	} else if (ln.z < -0.6 && lp.z < -0.85) {
		sc = symbol_cover(vec2(0.5 - lp.x / 0.6, 0.5 - (lp.y - 0.4) / 0.6)) * end_symbol_alpha;
	}
	c = mix(c, c * 0.5, sc.g * symbol_shadow * (1.0 - sc.r));
	c = mix(c, symbol_col, sc.r);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c += vec3(1.0, 0.95, 0.72) * highlight * (0.22 + 0.7 * fres);
	ALBEDO = c;
	ROUGHNESS = mix(0.55, 0.3, gold * COLOR.g);
	if (tarp > 0.5) {
		ROUGHNESS = 0.95;
	}
	METALLIC = 0.0;
	SPECULAR = 0.32;
	RIM = 0.18;
	RIM_TINT = 0.6;
	EMISSION = gold_col * gold * COLOR.g * 0.12;
}
