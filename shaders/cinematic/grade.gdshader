shader_type canvas_item;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
    vec3 scene = texture(scene_texture, SCREEN_UV).rgb;
    float luma = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    scene = mix(vec3(luma), scene, 0.88);
    scene = (scene - 0.18) * 1.09 + 0.18;
    vec2 p = (SCREEN_UV - vec2(0.5)) * vec2(1.1, 0.82);
    float vignette = 1.0 - 0.32 * smoothstep(0.12, 0.67, length(p));
    COLOR = vec4(max(scene, vec3(0.0)) * vec3(1.0, 0.97, 0.91) * vignette, 1.0);
}
