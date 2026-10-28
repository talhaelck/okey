shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform int surface_kind = 0; // wood, plaster, textile, leather, scales, fur
uniform float texture_scale = 1.0;
uniform float base_roughness = 0.7;
uniform float bump_strength = 0.15;
uniform bool vertical_grain = false;
varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	// Use physical dimensions, while keeping the pattern attached to moving objects.
	vec3 dimensions = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * dimensions;
}

void fragment() {
	vec3 p = local_pos * texture_scale;
	float grain = 0.5;
	float relief = 0.0;
	float variation = 0.12;
	if (surface_kind == 0) {
		if (vertical_grain) { p = p.yxz; }
		float warp = noise3(p * vec3(1.8, 7.0, 7.0));
		float long_grain = noise3(p * vec3(2.0, 105.0, 105.0) + vec3(0.0, warp * 4.0, warp * 4.0));
		float rings = sin((p.y + p.z) * 145.0 + warp * 13.0);
		grain = long_grain * 0.65 + rings * 0.15 + 0.18;
		variation = 0.48;
		relief = grain * 0.0015;
	} else if (surface_kind == 1) {
		grain = noise3(p * 3.0) * 0.55 + noise3(p * 30.0) * 0.25 + noise3(p * 180.0) * 0.2;
		variation = 0.32;
		relief = grain * 0.003;
	} else if (surface_kind == 2) {
		float weave = sin(p.x * 1600.0) * sin((p.y + p.z) * 1600.0);
		// Fade subpixel threads to avoid crawling/moire at normal gameplay distance.
		float weave_aa = 1.0 - smoothstep(0.5, 2.0, length(fwidth(p * 1600.0)));
		grain = noise3(p * 120.0) * 0.6 + 0.2 + weave * 0.2 * weave_aa;
		variation = 0.24;
		relief = grain * 0.0008;
	} else if (surface_kind == 3) {
		grain = noise3(p * 90.0) * noise3(p * 190.0);
		variation = 0.27;
		relief = grain * 0.0014;
	} else if (surface_kind == 4) {
		vec2 q = vec2(p.x + p.z * 0.45, p.y) * 140.0;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 cell = fract(q) - 0.5;
		float scale_pattern = 1.0 - smoothstep(0.26, 0.48, length(cell));
		float aa = 1.0 - smoothstep(0.5, 1.8, length(fwidth(q)));
		grain = mix(0.6, scale_pattern, aa) * 0.55 + noise3(p * 20.0) * 0.45;
		variation = 0.27;
		relief = grain * 0.0012;
	} else {
		grain = noise3(p * vec3(360.0, 70.0, 360.0)) * 0.6 + noise3(p * 40.0) * 0.4;
		variation = 0.16;
		relief = grain * 0.0006;
	}
	ALBEDO = tint.rgb * (1.0 + (grain - 0.5) * variation);
	ROUGHNESS = clamp(base_roughness + (grain - 0.5) * 0.12, 0.15, 1.0);
	SPECULAR = 0.3;
	// Derivative bump mapping works on rounded procedural meshes without UV tangents.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	vec3 gradient = sign(determinant) * (dFdx(relief) * r1 + dFdy(relief) * r2);
	if (abs(determinant) > 0.00000000001) {
		NORMAL = normalize(abs(determinant) * NORMAL - gradient * bump_strength);
	}
}
