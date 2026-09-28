shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D mask_texture : filter_linear_mipmap, repeat_disable;
uniform vec3 blood_color : source_color = vec3(0.24, 0.006, 0.012);
uniform float opacity = 1.0;
uniform bool instance_fade = false;
varying float instance_alpha;
void vertex() { instance_alpha = INSTANCE_CUSTOM.x; }
void fragment() {
    float mask = texture(mask_texture, UV).r;
    ALBEDO = blood_color;
    ROUGHNESS = 0.23;
    SPECULAR = 0.65;
    ALPHA = mask * opacity * (instance_fade ? instance_alpha : 1.0);
}
