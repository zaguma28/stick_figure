shader_type canvas_item;
render_mode unshaded;

#include "res://addons/shaderV/rgba/chromaticAberration.gdshaderinc"
#include "res://addons/shaderV/rgba/bloom.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 impact_tint : source_color = vec4(1.0, 0.78, 0.45, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_center = uv - vec2(0.5);
	float dist = length(to_center);
	float vignette = pow(clamp(1.0 - dist, 0.0, 1.0), 1.55);
	vec2 radial_dir = normalize(to_center + vec2(0.0001, 0.0));
	vec2 chroma_offset = radial_dir * impact_strength * (0.012 * vignette);
	vec4 col = _chromaticAberrationFunc(screen_texture, uv, vec3(chroma_offset, -1.0));
	col = _bloomFunc(col, impact_strength * 0.95);
	col.rgb += impact_tint.rgb * impact_strength * (0.28 * vignette);
	COLOR = col;
}
