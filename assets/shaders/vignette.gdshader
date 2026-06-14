shader_type canvas_item;

// Vignette shader - darkens screen edges in radial pattern
// Based on: innerRadius=150, outerRadius=360, innerColor=rgba(8,10,14,0), outerColor=rgba(8,10,14,0.46)

uniform float inner_radius : hint_range(0.0, 1.0) = 0.293; // 150/512 normalized
uniform float outer_radius : hint_range(0.0, 1.5) = 0.703; // 360/512 normalized
uniform vec3 vignette_color : source_color = vec3(0.031, 0.039, 0.055); // rgb(8,10,14)
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.46;

void fragment() {
	// Get the screen texture
	vec4 color = texture(TEXTURE, UV);

	// Calculate distance from center (0.5, 0.5)
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);

	// Create radial gradient falloff
	float vignette_amount = smoothstep(inner_radius, outer_radius, dist);

	// Apply vignette darkening
	vec3 vignette = mix(vec3(1.0), vignette_color, vignette_amount * vignette_opacity);

	COLOR = vec4(color.rgb * vignette, color.a);
}
