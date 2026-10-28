shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec3 color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	float vignette = smoothstep(0.4, 1.5, length(p));
	color *= 1.0 - vignette * 0.20;
	COLOR = vec4(color, 1.0);
}
