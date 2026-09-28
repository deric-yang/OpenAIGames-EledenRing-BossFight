shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    float edge=exp(-pow((UV.x-0.91)*38.0,2.0));
    float body=smoothstep(0.12,0.6,UV.x)*(1.0-smoothstep(0.86,1.0,UV.x));
    float wisps=noise(vec2(UV.x*42.0,UV.y*4.0+UV.x*2.0));
    float ends=smoothstep(0.0,0.22,UV.y)*smoothstep(1.0,0.91,UV.y);
    ALBEDO=vec3(0.88,0.93,1.0);
    EMISSION=vec3(0.17)*edge;
    ALPHA=COLOR.a*(edge*0.62+body*wisps*0.26)*ends;
}
