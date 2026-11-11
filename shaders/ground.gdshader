shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Toy Harbour ground (2.0): warm concrete quay in big clean slabs, a cool
// painted container yard, the parking apron, a safety line at the water's
// edge, crane rails, and grass behind the sheds. Pure math, no textures.

uniform vec3 concrete : source_color = vec3(0.925, 0.86, 0.74);
uniform vec3 yard_col : source_color = vec3(0.36, 0.49, 0.63);
uniform vec3 apron_col : source_color = vec3(0.36, 0.49, 0.63);
uniform vec3 grass : source_color = vec3(0.66, 0.86, 0.60);
uniform vec3 line_col : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 safety : source_color = vec3(1.0, 0.77, 0.2);
uniform vec4 yard_rect = vec4(0.0, 2.15, 5.6, 2.3);   // centre x, z, half size x, z
uniform vec4 apron_rect = vec4(0.0, -1.35, 3.4, 1.25);
uniform float quay_z = -3.2;
uniform float grass_z = 15.6;
uniform float slab = 2.6;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// slabs: each a hair lighter or darker, with soft joints
	vec2 sp = vec2(p.x + slab * 0.5, p.y - quay_z);
	vec2 cell = floor(sp / slab);
	vec2 f = fract(sp / slab) * slab;
	float joint = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, slab - f.x), min(f.y, slab - f.y)));
	vec3 col = concrete * (0.975 + 0.04 * hash(cell));
	col *= 1.0 - joint * 0.07;
	// crane rails
	float rail = max(1.0 - smoothstep(0.03, 0.06, abs(p.y + 2.75)), 1.0 - smoothstep(0.03, 0.06, abs(p.y - 0.05)));
	col = mix(col, concrete * 0.78, rail * 0.8);
	// parking apron: a slightly deeper tone so the pads sit in their own zone
	float da = rbox(p - apron_rect.xy, apron_rect.zw, 0.45);
	col = mix(col, apron_col * (0.985 + 0.02 * hash(floor(p / 1.3) + 7.0)), 1.0 - smoothstep(-0.015, 0.015, da));
	col = mix(col, line_col, 1.0 - smoothstep(0.035, 0.06, abs(da + 0.16)));
	// the yard: cool paint with a white outline
	float dy = rbox(p - yard_rect.xy, yard_rect.zw, 0.5);
	float inside = 1.0 - smoothstep(-0.015, 0.015, dy);
	vec3 yc = yard_col * (0.985 + 0.02 * hash(floor(p / 1.3)));
	col = mix(col, yc, inside);
	float border = 1.0 - smoothstep(0.035, 0.06, abs(dy + 0.16));
	col = mix(col, line_col, border);
	// safety line along the water's edge: yellow with dark dashes
	float dz = p.y - quay_z;
	float sl = 1.0 - smoothstep(0.075, 0.095, abs(dz - 0.42));
	float dash = step(0.5, fract(p.x / 1.3));
	col = mix(col, mix(safety, vec3(0.17, 0.28, 0.39), dash * 0.0), sl);
	// grass behind the sheds
	float g = smoothstep(grass_z - 0.05, grass_z + 0.05, p.y);
	vec3 gc = grass * (0.97 + 0.05 * sin(p.x * 0.9) * sin(p.y * 1.3));
	col = mix(col, gc, g);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
