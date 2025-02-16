shader_type spatial;
render_mode unshaded;

uniform sampler2D albedo_texture; // Assign the texture in the Inspector

void fragment() {
    // Calculate face normal for flat shading
    vec3 normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));

    // Convert normal to color range
    vec3 color = normal * 0.5 + 0.5;

    // Sample the texture using UV coordinates
    vec3 texture_color = texture(albedo_texture, UV).rgb;

    // Apply the texture color to the flat shading
    ALBEDO = texture_color * color;
}
