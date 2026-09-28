shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
    float height = 1.0 - UV.y;
    float sway = sin(height * 9.0 - TIME * 5.0) * 0.07 * height;
    float width = (1.0 - height) * 0.45;
    float edge = abs(UV.x - 0.5 + sway);
    float flame = 1.0 - smoothstep(width * 0.45, width + 0.035, edge);
    float flicker = 0.80 + 0.20 * sin(TIME * 8.0 + height * 15.0);
    ALBEDO = mix(vec3(1.0, 0.66, 0.12), vec3(0.8, 0.12, 0.025), height);
    ALPHA = flame * smoothstep(0.0, 0.10, height) * (1.0 - height) * flicker * 0.85;
}
