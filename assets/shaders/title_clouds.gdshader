shader_type canvas_item;

// Terra Chronicle - Title Screen Cloud Effect
// 26 radial gradient blobs drifting from left to right

uniform float time = 0.0;

// Pseudo-random function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = FRAGCOORD.xy / vec2(1920.0, 1080.0);
    vec4 color = vec4(0.0, 0.0, 0.0, 0.0);

    // 26 cloud blobs
    for (int i = 0; i < 26; i++) {
        float fi = float(i);

        // Pseudo-random properties for each blob
        float seed_x = hash(vec2(fi * 0.1, 0.0));
        float seed_y = hash(vec2(fi * 0.1, 1.0));
        float seed_r = hash(vec2(fi * 0.1, 2.0));
        float seed_v = hash(vec2(fi * 0.1, 3.0));

        // Blob properties
        float radius = 0.05 + seed_r * 0.15;  // 0.05 to 0.2
        float velocity = 0.3 + seed_v * 0.5;  // 0.3 to 0.8
        float y_pos = 0.1 + seed_y * 0.8;     // 0.1 to 0.9

        // Horizontal movement with wrapping
        float cycle_time = time * velocity * 0.4;  // 2.4s cycle at velocity 1.0
        float x_pos = mod(seed_x + cycle_time, 1.0);

        // Alpha fade in/out (first 30%, last 30%)
        float life = mod(cycle_time, 1.0);
        float alpha = 1.0;
        if (life < 0.3) {
            alpha = life / 0.3;
        } else if (life > 0.7) {
            alpha = (1.0 - life) / 0.3;
        }

        // Distance from blob center
        vec2 blob_pos = vec2(x_pos, y_pos);
        float dist = distance(uv, blob_pos);

        // Radial gradient
        float gradient = smoothstep(radius, 0.0, dist);

        // Center color: rgba(250, 248, 242, 0.95)
        vec3 blob_color = vec3(0.980, 0.973, 0.949);
        float blob_alpha = gradient * 0.95 * alpha;

        // Additive blending
        color.rgb += blob_color * blob_alpha;
        color.a = max(color.a, blob_alpha);
    }

    COLOR = color;
}
