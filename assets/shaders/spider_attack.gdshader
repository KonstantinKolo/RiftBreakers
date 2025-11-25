shader_type spatial;

uniform float wave_strength : hint_range(0.0, 1.0) = 0.0;
uniform float wave_position : hint_range(0.0, 5.0) = 0.0;

uniform sampler2D albedo_texture;

void fragment() {
    vec3 base = texture(albedo_texture, UV).rgb;

    float wave = smoothstep(wave_position - 0.2, wave_position, UV.y);

    vec3 red_tint = vec3(1.0, 0.1, 0.1);

    vec3 final_color = mix(base, red_tint, wave * wave_strength);

    ALBEDO = final_color;
}
