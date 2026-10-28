shader_type spatial;
render_mode unshaded;
varying vec2 pane;
void vertex() { pane = VERTEX.xy; }
float hash(float v) { return fract(sin(v * 127.1) * 43758.5453); }
void fragment() {
	vec2 p = pane;
	float column = floor(p.x * 85.0);
	float x = fract(p.x * 85.0) - 0.5;
	float y = fract(p.y * 1.7 + TIME * (0.035 + hash(column) * 0.07) + hash(column + 7.0));
	float rain = exp(-x*x*120.0) * smoothstep(0.55, 0.97, y) * (1.0 - smoothstep(0.97, 1.0, y));
	vec3 night = mix(vec3(0.015, 0.035, 0.048), vec3(0.055, 0.14, 0.17), clamp(p.y + 0.5, 0.0, 1.0));
	float city = step(p.y, -0.22 + hash(floor(p.x * 9.0)) * 0.28);
	night *= 1.0 - city * 0.65;
	ALBEDO = night + vec3(0.12, 0.24, 0.25) * rain;
}
