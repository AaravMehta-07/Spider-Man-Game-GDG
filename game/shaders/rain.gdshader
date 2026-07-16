shader_type canvas_item;
uniform vec4 color : source_color = vec4(1.0, 0.02, 0.12, 0.7);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 centered = UV - vec2(0.5);
    float edge = smoothstep(0.28, 0.72, length(centered));
    COLOR = vec4(color.rgb, color.a * edge * strength);
}