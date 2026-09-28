shader_type spatial;
render_mode cull_disabled;
varying vec3 point;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { point=VERTEX; }
void fragment() {
    float grit=hash(floor(point*65.0));
    float strata=sin(point.y*47.0+sin(point.x*12.0)*2.0)*0.035;
    ALBEDO=vec3(0.245,0.185,0.127)*(0.75+grit*0.4+strata)*COLOR.rgb;
    ROUGHNESS=0.98;
}
