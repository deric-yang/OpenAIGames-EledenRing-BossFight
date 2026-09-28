shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float rings = exp(-abs(r - 0.88) * 240.0) + exp(-abs(r - 0.73) * 230.0);
    rings += exp(-abs(r - 0.39) * 180.0);
    float angular = abs(sin(a * 24.0 + r * 24.0));
    float rune = (1.0 - smoothstep(0.06, 0.22, angular)) * smoothstep(0.44, 0.50, r) * (1.0 - smoothstep(0.66, 0.69, r));
    float rays = pow(max(0.0, cos(a * 12.0)), 28.0) * smoothstep(0.09, 0.14, r) * (1.0 - smoothstep(0.28, 0.36, r));
    float halo = exp(-r * r * 4.0) * 0.12;
    float pulse = 0.78 + 0.18 * sin(TIME * 1.4);
    ALBEDO = vec3(1.0, 0.61, 0.13);
    ALPHA = min(1.0, (rings + rune + rays + halo) * pulse);
}
