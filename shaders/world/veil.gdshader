shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 veil_color : source_color = vec4(0.55, 0.32, 0.4, 0.36);
uniform float phase = 0.0;
uniform float sway_amount = 0.24;

void vertex() {
    float edge_weight = sin(UV.x * 3.14159265);
    VERTEX.x += sin(TIME * 0.55 + phase + UV.y * 2.7) * sway_amount * edge_weight * UV.y;
    VERTEX.z += cos(TIME * 0.42 + phase + UV.x * 4.0) * 0.08 * UV.y;
}

void fragment() {
    float left_edge = smoothstep(0.0, 0.16, UV.x);
    float right_edge = smoothstep(0.0, 0.16, 1.0 - UV.x);
    float bottom_edge = smoothstep(0.0, 0.12, UV.y);
    float top_edge = smoothstep(0.0, 0.08, 1.0 - UV.y);
    float torn_variation = 0.88 + 0.12 * sin(UV.x * 18.0 + UV.y * 5.0);
    ALBEDO = veil_color.rgb;
    ALPHA = veil_color.a * left_edge * right_edge * bottom_edge * top_edge * torn_variation;
}
