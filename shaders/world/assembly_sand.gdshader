shader_type spatial;

varying vec3 world_pos;

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + vec2(1, 0), vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0, 1), vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + vec2(1, 1), vec2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_pos.xz;
    // World-space domain warping prevents repeated tiles and uninterrupted stripes.
    vec2 warp = vec2(noise(p * 0.029), noise(p * 0.037 + vec2(91.2, 43.7)));
    vec2 q = p + (warp - 0.5) * 13.0;
    float broad = noise(q * 0.041) * 0.60 + noise(q * 0.137 + 21.7) * 0.27;
    broad += noise(q * 0.39 + 67.1) * 0.13;
    float grain = noise(p * 23.1 + 13.4);
    float wind = sin(q.x * 7.9 + q.y * 2.1 + noise(q * 0.53) * 12.0);
    float ripple_mask = smoothstep(0.35, 0.72, noise(q * 0.19 + 11.8));
    float ripple = wind * ripple_mask * 0.006;
    float ash = smoothstep(0.67, 0.84, noise(q * 0.081 + 33.2));
    ALBEDO = mix(vec3(0.12, 0.09, 0.065), vec3(0.26, 0.20, 0.13), broad);
    ALBEDO = mix(ALBEDO, vec3(0.115, 0.11, 0.105), ash * 0.52);
    float detail_fade = 1.0 - smoothstep(0.04,0.20,length(fwidth(p)));
    ALBEDO += ((grain - 0.5) * 0.014 + ripple) * detail_fade;
    ROUGHNESS = 0.93 + grain * 0.055;
}
