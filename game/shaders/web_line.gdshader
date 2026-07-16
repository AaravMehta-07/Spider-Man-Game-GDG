shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
uniform vec4 web_color : source_color = vec4(0.72, 0.94, 1.0, 1.0);
uniform float tension : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    float core = smoothstep(0.5, 0.05, abs(UV.x - 0.5));
    ALBEDO = web_color.rgb;
    EMISSION = web_color.rgb * (1.5 + tension * 4.0) * core;
    ALPHA = core;
}