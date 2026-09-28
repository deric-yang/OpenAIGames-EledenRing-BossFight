shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.72, 0.61, 0.46, 0.075);
uniform float seed = 0.0;
uniform bool shaft = false;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 p=UV*vec2(4.5,2.0)+vec2(TIME*0.008+seed,seed);
    float mist=noise(p)*0.65+noise(p*2.73)*0.35;
    float edge=pow(max(0.0,sin(UV.x*3.14159)*sin(UV.y*3.14159)),1.8);
    if (shaft) edge=pow(max(0.0,sin(UV.x*3.14159)),3.0)*smoothstep(0.0,0.2,UV.y)*(1.0-smoothstep(0.65,1.0,UV.y));
    ALBEDO=tint.rgb;
    ALPHA=tint.a*edge*mix(0.35,1.0,mist);
}
