shader_type canvas_item;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    float n = noise(UV * vec2(18.0, 5.0) + vec2(TIME * 0.25, -TIME * 0.13));
    n += 0.45 * noise(UV * vec2(37.0, 9.0) - TIME * 0.18);
    float edge = abs(UV.y - 0.5) * 2.0;
    float mask = 1.0 - smoothstep(0.28, 1.0, edge + (n - 0.7) * 0.38);
    mask *= smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0 - UV.x);
    COLOR = vec4(vec3(0.015, 0.014, 0.012), mask * 0.86) * COLOR;
}
