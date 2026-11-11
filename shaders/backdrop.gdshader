shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
// Backdrop ridges: vertex colour shaded softly; alpha blends towards the
// horizon colour of the current atmosphere (aerial perspective).
uniform vec3 haze_col : source_color = vec3(0.8, 0.91, 0.97);

varying float haze;

void vertex() {
	haze = COLOR.a;
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c, haze_col, haze * 0.85);
	// distant layers take less direct light so they read as far away
	ROUGHNESS = 1.0;
	EMISSION = haze_col * haze * 0.25;
}
