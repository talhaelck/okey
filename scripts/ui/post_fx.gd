class_name PostFx
extends CanvasLayer
## Cinematic finish over the 3D view (under the HUD): soft vignette and fine animated film grain.

const SHADER := """
shader_type canvas_item;
uniform float vignette = 0.55;
uniform float grain = 0.05;

void fragment() {
	vec2 uv = (SCREEN_UV - 0.5) * vec2(1.0, 0.85);
	float dark = smoothstep(0.3, 0.85, length(uv)) * vignette;
	float n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 37.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(n * grain * 6.0), max(dark, grain));
}
"""


func _ready() -> void:
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	add_child(rect)
