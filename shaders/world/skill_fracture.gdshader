shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float front = 1.0;
uniform float fade = 1.0;
uniform float heat = 0.0;
void fragment() {
    float grow=1.0-smoothstep(front-0.045,front,UV.y);
    float seam=1.0-smoothstep(0.07,0.35,abs(UV.x-0.5));
    ALBEDO=mix(vec3(0.065,0.037,0.023),vec3(0.9,0.09,0.008)*seam,heat);
    EMISSION=vec3(0.75,0.055,0.005)*seam*heat*0.5;
    ALPHA=grow*fade*smoothstep(0.5,0.32,abs(UV.x-0.5));
}
