shader_type sky;

void sky() {
    float height = max(EYEDIR.y, 0.0);
    vec3 haze = vec3(0.36, 0.30, 0.24);
    vec3 zenith = vec3(0.075, 0.09, 0.12);
    float cloud = sin(EYEDIR.x * 11.0 + EYEDIR.z * 7.0 + height * 21.0);
    cloud += sin(EYEDIR.x * 19.0 - EYEDIR.z * 5.0 + height * 34.0) * 0.4;
    COLOR = mix(haze, zenith, smoothstep(0.0, 0.85, height));
    COLOR += vec3(0.04, 0.03, 0.015) * cloud * smoothstep(0.03, 0.2, height);
}
