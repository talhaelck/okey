shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float left = 1.0-smoothstep(0.24,0.78,UV.x);
	float edge = smoothstep(0.24,0.8,abs(UV.y-0.5));
	COLOR = vec4(vec3(0.035,0.018,0.012),clamp(left*0.92+edge*0.4,0.0,0.96));
}
