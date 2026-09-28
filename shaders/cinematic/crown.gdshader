shader_type spatial;
render_mode cull_disabled;
uniform float cutscene_time = 0.0;
varying vec3 crown_position;

// Kept identical to CrownProp.release_time(), including the normalization bounds.
float release_time(vec3 p) {
    float noise = sin(p.x * 19.0 + p.z * 13.0) * sin(p.y * 25.0 - p.z * 17.0);
    float field = clamp((p.y + 0.08) / 0.94 + noise * 0.065, 0.0, 1.0);
    return 0.7 + 6.0 * field;
}
void vertex() { crown_position = VERTEX; }
void fragment() {
    float birth = release_time(crown_position);
    if (cutscene_time >= birth) discard;
    float grain = fract(sin(dot(floor(crown_position * 360.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    float tarnish = 0.5 + 0.5 * sin(crown_position.x * 34.0 + sin(crown_position.y * 48.0)) * sin(crown_position.z * 41.0);
    vec3 gold = mix(vec3(0.20, 0.105, 0.029), vec3(0.68, 0.42, 0.13), tarnish * 0.65 + grain * 0.20);
    float powder = 1.0 - smoothstep(0.0, 0.23, birth - cutscene_time);
    ALBEDO = mix(gold, vec3(0.58, 0.40, 0.20) * (0.7 + 0.3 * grain), powder);
    METALLIC = mix(0.78, 0.05, powder);
    ROUGHNESS = mix(0.38 + 0.2 * tarnish, 0.93, powder);
}
