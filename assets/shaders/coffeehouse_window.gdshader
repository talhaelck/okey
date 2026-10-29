shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 room_position;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void vertex() {
	room_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = (room_position.x - 2.20);
	float y = room_position.y;

	// Rich Istanbul evening / dusk sky gradient (warm amber-crimson horizon -> deep indigo night sky)
	vec3 horizon_col = vec3(0.82, 0.38, 0.16);
	vec3 mid_sky = vec3(0.28, 0.17, 0.28);
	vec3 zenith_col = vec3(0.05, 0.08, 0.16);
	vec3 sky = mix(horizon_col, mid_sky, smoothstep(1.10, 1.78, y));
	sky = mix(sky, zenith_col, smoothstep(1.70, 2.75, y));

	// Subtle dusk clouds
	float c_noise = noise(u * 4.5 + 1.2) * 0.6 + noise(u * 11.0) * 0.4;
	float cloud = exp(-pow((y - 1.68 - c_noise * 0.12) * 6.0, 2.0)) * c_noise;
	sky += vec3(0.28, 0.11, 0.05) * cloud;

	// Distant historic peninsula / mosque dome & minaret on left side of window (u ~ -0.36)
	float hill_far = 1.28 + noise(u * 3.2 + 4.0) * 0.12;
	float dome_d = length(vec2((u + 0.36) * 1.1, (y - 1.38) * 1.4));
	bool in_dome = (dome_d < 0.095) && (y > 1.34);
	bool in_minaret = (abs(u + 0.48) < 0.011 && y >= 1.28 && y <= 1.62) || (abs(u + 0.24) < 0.011 && y >= 1.28 && y <= 1.58);
	bool in_minaret_tip = (abs(u + 0.48) < mix(0.012, 0.001, clamp((y - 1.62) / 0.08, 0.0, 1.0)) && y > 1.62 && y <= 1.70)
		|| (abs(u + 0.24) < mix(0.012, 0.001, clamp((y - 1.58) / 0.08, 0.0, 1.0)) && y > 1.58 && y <= 1.66);

	// Foreground Galata hillside & Galata Tower centered at u = 0.05
	float hill_near = 1.24 + noise(u * 5.0 + 1.7) * 0.14 + step(0.0, u + 0.15) * 0.08;
	float dx = abs(u - 0.05);
	bool in_tower_shaft = (dx < 0.086) && (y >= 1.22 && y <= 1.98);
	bool in_tower_cornice = (dx < 0.100) && (y > 1.95 && y <= 2.02);
	float cone_t = clamp((y - 2.02) / 0.28, 0.0, 1.0);
	bool in_tower_cone = (dx < mix(0.096, 0.004, cone_t)) && (y > 2.02 && y <= 2.30);
	bool in_tower_spire = (dx < 0.005) && (y > 2.30 && y <= 2.40);
	bool is_galata = in_tower_shaft || in_tower_cornice || in_tower_cone || in_tower_spire;

	vec3 color = sky;

	// Far silhouette layer
	if (y < hill_far || in_dome || in_minaret || in_minaret_tip) {
		color = vec3(0.12, 0.08, 0.13);
	}

	// Near Galata hill & Tower layer
	if (y < hill_near || is_galata) {
		vec3 sil = vec3(0.06, 0.04, 0.06);
		if (is_galata) {
			float cyl_shade = smoothstep(-0.08, 0.08, u - 0.05);
			sil = mix(vec3(0.08, 0.05, 0.06), vec3(0.28, 0.15, 0.09), cyl_shade * float(in_tower_shaft));
			// Illuminated arched observation gallery windows
			if (y > 1.88 && y < 1.94 && dx < 0.076) {
				float w_arch = smoothstep(0.28, 0.35, fract((u - 0.05) * 30.0)) * smoothstep(0.85, 0.78, fract((u - 0.05) * 30.0));
				sil = mix(sil, vec3(1.0, 0.68, 0.25), w_arch * 0.90);
			}
			if (y > 1.70 && y < 1.75 && dx < 0.060) {
				float w_mid = step(0.45, fract((u - 0.05) * 22.0));
				sil = mix(sil, vec3(0.95, 0.56, 0.20), w_mid * 0.75);
			}
		} else if (y > 1.18) {
			// Warm distant house lights on the hillside
			vec2 cell = fract(vec2(u * 28.0, y * 26.0));
			float win = step(0.35, cell.x) * step(cell.x, 0.65) * step(0.32, cell.y) * step(cell.y, 0.68);
			float lit = step(0.72, hash(floor(u * 28.0) + floor(y * 26.0) * 41.0));
			sil += vec3(0.70, 0.38, 0.14) * win * lit;
		}
		color = sil;
	}

	// Calm dark Bosphorus water at the bottom (y < 1.18) with soft vertical golden yakamoz shimmer
	if (y < 1.18) {
		float wt = clamp((1.18 - y) / 0.22, 0.0, 1.0);
		vec3 water = mix(vec3(0.14, 0.09, 0.13), vec3(0.04, 0.06, 0.10), wt);
		float shimmer = 0.65 + 0.35 * sin(y * 95.0 + TIME * 1.6) * cos(u * 18.0 + y * 40.0);
		float yakamoz = exp(-abs(u - 0.05) * 5.5) * shimmer * (1.0 - wt * 0.5);
		water += vec3(0.68, 0.34, 0.12) * yakamoz * 0.48;
		color = water;
	}

	ALBEDO = color;
}
