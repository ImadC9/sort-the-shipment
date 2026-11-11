shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Toy Harbour water (2.0): a calm turquoise sheet that deepens away from the
// quay, a slow net of light on top, soft double foam lines along the quay wall
// and round each hull, and a few sun sparkles. Flat and readable on purpose.

uniform vec3 shallow : source_color = vec3(0.29, 0.83, 0.85);
uniform vec3 deep : source_color = vec3(0.13, 0.56, 0.86);
uniform vec3 sky_tint : source_color = vec3(0.85, 0.95, 1.0);
uniform vec3 foam_col : source_color = vec3(1.0);
uniform float quay_z = -3.2;
uniform float wave_amp = 0.03;
// xy = ship position (x, z), z = ship scale, w = foam strength
uniform vec4 ships[4];

varying vec3 wpos;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// distance to the nearest cell border of a drifting Voronoi net
float net(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.38 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(w.x * 0.5 + TIME * 1.1) + sin(w.z * 0.7 - TIME * 0.9)) * wave_amp;
	wpos = w;
}

void fragment() {
	vec2 uv = wpos.xz;
	float dist = clamp((quay_z - wpos.z) / 11.0, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, dist));
	// broad, slow bands of slightly lighter water
	col *= 0.97 + 0.05 * sin(uv.x * 0.35 + uv.y * 0.6 + TIME * 0.25);
	// the net of light
	vec2 warp = vec2(sin(uv.y * 0.8 + TIME * 0.5), cos(uv.x * 0.7 - TIME * 0.4)) * 0.18;
	float n = net(uv * 1.25 + warp, TIME * 0.55);
	float line = 1.0 - smoothstep(0.015, 0.075, n);
	col = mix(col, sky_tint, line * mix(0.13, 0.04, dist));
	// cells shimmer a touch lighter towards their middle
	col += vec3(0.03, 0.05, 0.05) * smoothstep(0.1, 0.5, n) * (1.0 - dist);
	// soft shade under the quay wall
	float d_quay = quay_z - wpos.z;
	col *= 1.0 - 0.16 * smoothstep(1.3, 0.0, d_quay);
	// foam: a solid wavy lip on the wall and a thinner line a little way out
	float wob = sin(wpos.x * 2.3 + TIME * 1.3) * 0.05 + sin(wpos.x * 5.1 - TIME * 0.9) * 0.025;
	float foam = 1.0 - smoothstep(0.13, 0.17, d_quay + wob);
	float pulse = fract(TIME * 0.16);
	float ring_d = 0.34 + pulse * 0.5;
	foam += (1.0 - smoothstep(0.02, 0.05, abs(d_quay + wob * 1.6 - ring_d))) * (1.0 - pulse) * 0.6;
	for (int i = 0; i < 4; i++) {
		vec4 sh = ships[i];
		if (sh.z <= 0.0) {
			continue;
		}
		vec2 d = (uv - sh.xy) / (vec2(2.84, 1.44) * sh.z);
		// squarer than an ellipse, to hug the hull's plan shape
		float r = pow(pow(abs(d.x), 3.0) + pow(abs(d.y), 3.0), 1.0 / 3.0);
		float ang = atan(d.y, d.x);
		float w2 = sin(ang * 9.0 + TIME * 1.6) * 0.012 + sin(ang * 17.0 - TIME * 1.1) * 0.008;
		float lip = 1.0 - smoothstep(1.035, 1.06, r + w2);
		float moving = smoothstep(0.3, 1.0, sh.w);
		float out_r = 1.12 + 0.07 * sin(TIME * 0.9 + float(i) * 2.0) + moving * 0.12;
		float ring = 1.0 - smoothstep(0.012, 0.03, abs(r + w2 * 1.5 - out_r));
		foam += lip * step(0.9, r) + ring * mix(0.45, 0.9, moving);
	}
	col = mix(col, foam_col, clamp(foam, 0.0, 1.0) * 0.92);
	// sun sparkles: small round glints that blink
	vec2 gq = uv * 1.6 + vec2(0.0, TIME * 0.15);
	vec2 cell = floor(gq);
	vec2 gf = fract(gq) - 0.5;
	vec2 h = hash2(cell);
	float life = fract(h.x + TIME * 0.3);
	float on = step(0.86, h.y) * smoothstep(0.0, 0.25, life) * smoothstep(0.7, 0.3, life);
	col += vec3(on * smoothstep(0.1, 0.03, length(gf * vec2(1.0, 1.9)))) * 0.5 * (1.0 - dist * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
