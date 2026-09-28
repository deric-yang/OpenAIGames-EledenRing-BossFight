shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

void fragment() {
    float r = length(UV * 2.0 - 1.0);
    ALBEDO = vec3(1.0, 0.65, 0.16);
    ALPHA = pow(max(0.0, 1.0 - r), 2.5);
}
