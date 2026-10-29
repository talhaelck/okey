shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
void fragment() {
	float edge = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),3.0);
	ALBEDO = vec3(0.80,0.89,0.93);
	ROUGHNESS = 0.12;
	SPECULAR = 0.55;
	ALPHA = mix(0.018,0.24,edge);
}
