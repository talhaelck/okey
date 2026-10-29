shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 room_position;
float noise(float v) { return fract(sin(v * 127.1) * 43758.5453); }
void vertex() { room_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(room_position.z, room_position.y);
	vec3 sky = mix(vec3(0.021,0.047,0.058), vec3(0.061,0.108,0.125), smoothstep(0.8,2.9,p.y));
	float column = floor(p.x*7.0);
	float roof = 1.35 + noise(column)*0.40;
	float buildings = 1.0-smoothstep(roof,roof+0.012,p.y);
	sky = mix(sky,vec3(0.012,0.024,0.030),buildings);
	vec2 cell = fract(vec2(p.x*21.0,p.y*19.0));
	float panes = step(0.35,cell.x)*step(cell.x,0.66)*step(0.35,cell.y)*step(cell.y,0.67);
	panes *= step(0.76,noise(floor(p.x*21.0)+floor(p.y*19.0)*31.0))*buildings;
	sky += vec3(0.28,0.14,0.045)*panes;
	float moon = 1.0-smoothstep(0.062,0.075,length(p-vec2(-0.42,2.52)));
	float halo = exp(-length(p-vec2(-0.42,2.52))*6.0);
	sky += vec3(0.22,0.25,0.23)*moon + vec3(0.018,0.028,0.032)*halo;
	float streak = pow(max(0.0,1.0-abs(fract(p.x*77.0)-0.5)*2.0),18.0);
	streak *= smoothstep(0.65,0.98,fract(p.y*1.7+TIME*0.04+noise(floor(p.x*77.0))));
	ALBEDO = sky + vec3(0.012,0.02,0.023)*streak;
}
