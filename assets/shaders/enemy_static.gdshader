shader_type spatial;

uniform float time : hint_range(0.0, 10.0);
uniform float noise_strength : hint_range(0.0, 1.0) = 0.1;
uniform float transparency : hint_range(0.0, 1.0) = 0.5; // Transparency level (0 = fully transparent, 1 = opaque)
uniform vec3 noise_color : source_color = vec3(1.0, 0.992, 0.749); // Default color (#FFFBCF)

void fragment() {
    // Create random noise based on UVs and time
    vec2 uv = FRAGCOORD.xy / vec2(1280.0, 720.0); // Screen or texture resolution
    float noise = fract(sin(dot(uv + time, vec2(12.9898, 78.233))) * 43758.5453);

    // Mix the noise with the specified color
    vec3 color = noise_color * noise * noise_strength;

    ALBEDO = color;
    EMISSION = color; // Make it glow like static noise

    // Set transparency
    ALPHA = transparency;
}
