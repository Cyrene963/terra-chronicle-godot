shader_type canvas_item;

// Soft light shader - subtle bloom/glow effect with warm tone enhancement
// Based on: blend add, tint=0xe89646 (golden), alpha=dusk*0.34, size=vw*1.5,vh*1.2

uniform sampler2D glow_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 tint_color : source_color = vec3(0.910, 0.588, 0.275); // #e89646 golden
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.34;
uniform vec2 glow_scale = vec2(1.5, 1.2); // Size multiplier relative to viewport
uniform vec2 glow_offset = vec2(0.5, 0.55); // Position (normalized center)

void fragment() {
	// Get the base screen texture
	vec4 base_color = texture(TEXTURE, UV);

	// Calculate UV coordinates for the glow texture
	// Center the glow based on offset and scale
	vec2 glow_uv = (UV - glow_offset) / glow_scale + vec2(0.5);

	// Sample the glow texture
	vec4 glow = texture(glow_texture, glow_uv);

	// Apply golden tint to the glow
	vec3 tinted_glow = glow.rgb * tint_color;

	// Additive blend with intensity control
	vec3 final_color = base_color.rgb + (tinted_glow * glow_intensity * glow.a);

	// Enhance warm tones slightly
	final_color.r = mix(final_color.r, final_color.r * 1.05, 0.3);
	final_color.g = mix(final_color.g, final_color.g * 0.98, 0.2);

	COLOR = vec4(final_color, base_color.a);
}
