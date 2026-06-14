shader_type canvas_item;

uniform float time;

// Hash function for pseudo-random number generation
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Generate blob properties based on index
vec4 get_blob_properties(int i) {
    float fi = float(i);
    float x = hash(fi * 1.234);
    float y = hash(fi * 2.345);
    float radius = hash(fi * 3.456) * 0.15 + 0.05; // 0.05 to 0.2
    float velocity = hash(fi * 4.567) * 0.5 + 0.3; // 0.3 to 0.8
    return vec4(x, y, radius, velocity);
}

// Calculate alpha fade based on lifetime progress
float calculate_fade(float progress) {
    if (progress < 0.3) {
        // Fade in during first 30%
        return progress / 0.3;
    } else if (progress > 0.7) {
        // Fade out during last 30%
        return (1.0 - progress) / 0.3;
    }
    return 1.0;
}

void fragment() {
    vec2 uv = UV;
    vec3 base_color = vec3(250.0/255.0, 248.0/255.0, 242.0/255.0);
    float total_alpha = 0.0;

    // Duration for one full cycle in seconds (2.4ms = 2.4 seconds assuming 2.4ms was meant as 2.4s)
    float cycle_duration = 2.4;

    // Render 26 blobs
    for (int i = 0; i < 26; i++) {
        vec4 props = get_blob_properties(i);
        float start_x = props.x;
        float start_y = props.y;
        float radius = props.z;
        float velocity = props.w;

        // Calculate current position with wrapping
        float progress = mod(time * velocity / cycle_duration, 1.0);
        float current_x = mod(start_x + progress, 1.0);
        float current_y = start_y;

        // Distance from current blob center
        vec2 blob_center = vec2(current_x, current_y);
        float dist = distance(uv, blob_center);

        // Radial gradient: center opaque → edge transparent
        float gradient = 1.0 - smoothstep(0.0, radius, dist);

        // Apply fade based on lifecycle
        float fade = calculate_fade(progress);

        // Accumulate alpha (additive blending)
        total_alpha += gradient * fade * 0.95;
    }

    // Clamp alpha to valid range
    total_alpha = clamp(total_alpha, 0.0, 1.0);

    // Output color with accumulated alpha
    COLOR = vec4(base_color, total_alpha);
}
