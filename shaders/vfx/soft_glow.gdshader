shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.1,0.015,0.6);
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,length(MODEL_MATRIX[2].xyz),0),vec4(0,0,0,1));
}
void fragment() {
    vec2 p = (UV-0.5)*2.0;
    float halo = exp(-dot(p,p)*5.0)*(1.0-smoothstep(0.65,1.0,length(p)));
    float core = exp(-dot(p*vec2(1.0,3.5),p*vec2(1.0,3.5))*14.0);
    ALBEDO = tint.rgb*(0.65+core*2.0);
    ALPHA = (halo*0.6+core*0.5)*tint.a;
}
