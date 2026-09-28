shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform float cutscene_time = 0.0;
varying float alive;
varying float shade;
void vertex() {
    float age = cutscene_time - INSTANCE_CUSTOM.x;
    float seed = INSTANCE_CUSTOM.y;
    float ground_y = INSTANCE_CUSTOM.z;
    float life = INSTANCE_CUSTOM.w;
    vec3 origin = MODEL_MATRIX[3].xyz;
    float t = max(age, 0.0);
    float height = max(origin.y - ground_y, 0.01);
    float fall_time = (sqrt(0.09 + 19.6 * height) - 0.3) / 9.8;
    float fall = min(t, fall_time);
    vec3 drift = vec3((0.13 + seed * 0.17) * fall + 0.12 * fall * fall,
        -0.3 * fall - 4.9 * fall * fall,
        sin(seed * 29.0) * 0.09 * fall);
    float settled = max(0.0, t - fall_time);
    drift.x += (0.13 + seed * 0.08) * (1.0 - exp(-settled * 5.0));
    drift.z += sin(seed * 71.0) * 0.06 * (1.0 - exp(-settled * 4.0));
    alive = step(0.0, age) * (1.0 - step(life, age));
    float size = alive * (1.0 - smoothstep(life - 0.4, life, age));
    VERTEX = origin + (VERTEX - origin) * size + drift;
    shade = seed;
}
void fragment() {
    if (alive < 0.5) discard;
    ALBEDO = mix(vec3(0.34, 0.25, 0.13), vec3(0.78, 0.64, 0.39), shade);
    ROUGHNESS = 0.92;
    METALLIC = 0.06;
}
