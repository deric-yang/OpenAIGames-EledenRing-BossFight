shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D body_texture : source_color, filter_linear_mipmap;
uniform bool textured = false;
uniform vec3 body_tint : source_color = vec3(1.0);
uniform float progress = -0.1;
uniform vec3 body_color : source_color = vec3(0.32, 0.39, 0.44);
uniform vec3 edge_color : source_color = vec3(1.0, 0.33, 0.035);
varying vec3 surface_position;
void vertex() { surface_position = VERTEX; }
void fragment() {
    float noise = texture(source_noise, surface_position.xy * 0.8).r;
    float field = clamp(surface_position.y / 2.2, 0.0, 1.0) * 0.72 + noise * 0.28;
    if (field < progress) { discard; }
    float edge = 1.0 - smoothstep(0.008, 0.045, field - progress);
    vec3 base = textured ? texture(body_texture, UV).rgb * body_tint : body_color;
    ALBEDO = mix(base, edge_color, edge * 0.7);
    METALLIC = 0.68;
    ROUGHNESS = 0.35;
    EMISSION = edge_color * edge * 3.0;
}
