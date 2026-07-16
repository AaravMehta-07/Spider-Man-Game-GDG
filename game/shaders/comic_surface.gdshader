shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.08, 0.1, 0.16, 1.0);
uniform float ink_strength : hint_range(0.0, 1.0) = 0.32;
void fragment() {
    float light_steps = floor(max(dot(NORMAL, normalize(vec3(0.4, 0.8, 0.2))), 0.0) * 4.0) / 4.0;
    float edge = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
    ALBEDO = base_color.rgb * (0.35 + light_steps * 0.8) * (1.0 - edge * ink_strength);
    ROUGHNESS = 0.62;
}