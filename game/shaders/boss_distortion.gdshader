shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform vec4 veil_color : source_color = vec4(0.025, 0.045, 0.08, 0.68);
uniform vec4 crack_color : source_color = vec4(1.0, 0.02, 0.16, 1.0);
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 8.0) = 2.0;

void vertex() {
    float wave = sin(VERTEX.y * 3.1 + TIME * 5.0) * cos(VERTEX.x * 2.7 - TIME * 3.0);
    VERTEX += NORMAL * wave * (0.07 + damage * 0.12);
}

void fragment() {
    float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.2);
    float bands = smoothstep(0.72, 0.94, sin((VERTEX.y + VERTEX.x) * 13.0 + TIME * 7.0) * 0.5 + 0.5);
    ALBEDO = veil_color.rgb + crack_color.rgb * bands * damage;
    METALLIC = 0.7;
    ROUGHNESS = 0.15;
    EMISSION = crack_color.rgb * (fresnel * pulse + bands * damage * 5.0 + tension * 2.0);
    ALPHA = clamp(veil_color.a + fresnel * 0.45 + damage * bands * 0.4, 0.12, 0.95);
}
