shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 felt_color : source_color = vec4(0.08, 0.27, 0.15, 1.0);
varying vec3 surface_position;

float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	surface_position = VERTEX;
}

void fragment() {
	vec2 p = surface_position.xz;
	float nap = grain(floor(p * 9000.0));
	float weave = sin(p.x * 520.0) * sin(p.y * 520.0) * 0.035;

	// Rich cloth base with micro-fiber variations
	vec3 base = felt_color.rgb * (0.96 + nap * 0.05 + weave);

	// Velvety cloth rim sheen on glancing angles
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float velvet = pow(rim, 3.4) * 0.38;
	base += felt_color.rgb * velvet;

	// Anatolian geometric border pattern near table edge
	float edge = max(abs(p.x), abs(p.y));
	float band = smoothstep(0.485, 0.489, edge) * (1.0 - smoothstep(0.530, 0.534, edge));
	float coordinate = abs(p.x) > abs(p.y) ? p.y : p.x;
	float diamond = abs(fract(coordinate * 24.0) - 0.5) + abs((edge - 0.51) * 38.0);
	float thread = (1.0 - smoothstep(0.30, 0.34, diamond)) * band;
	base = mix(base, vec3(0.36, 0.24, 0.09), thread * 0.55);

	ALBEDO = base;
	ROUGHNESS = 0.90 + nap * 0.04;
	SPECULAR = 0.12;
}

