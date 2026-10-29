shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 felt_color : source_color = vec4(0.105,0.235,0.165,1.0);
varying vec3 surface_position;
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { surface_position = VERTEX; }
void fragment() {
	float nap = grain(floor(surface_position.xz*11000.0));
	ALBEDO = felt_color.rgb * (0.975 + nap*0.045);
	// A restrained woven border stays clear of the central tile area.
	vec2 p = surface_position.xz;
	float edge = max(abs(p.x),abs(p.y));
	float band = smoothstep(0.485,0.489,edge)*(1.0-smoothstep(0.530,0.534,edge));
	float coordinate = abs(p.x)>abs(p.y) ? p.y : p.x;
	float diamond = abs(fract(coordinate*24.0)-0.5)+abs((edge-0.51)*38.0);
	float thread = (1.0-smoothstep(0.30,0.34,diamond))*band;
	ALBEDO = mix(ALBEDO,vec3(0.30,0.19,0.075),thread*0.45);
	ROUGHNESS = 0.94 + nap*0.035;
	SPECULAR = 0.15;
}
