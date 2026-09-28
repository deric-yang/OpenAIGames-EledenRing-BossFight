shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D cloud : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.55,0.43,0.31,0.64);
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool jet = false;
varying vec4 particle;
void vertex() {
    particle = INSTANCE_CUSTOM;
    if (jet) {
        vec3 axis=normalize((VIEW_MATRIX*vec4(MODEL_MATRIX[1].xyz,0.0)).xyz);
        vec3 up=normalize(vec3(axis.xy,0.0));
        vec3 right=vec3(up.y,-up.x,0.0);
        MODELVIEW_MATRIX=mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),
            vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(0,0,1,0),VIEW_MATRIX*MODEL_MATRIX[3]);
    } else {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
    MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
    MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
    }
}
void fragment() {
    float angle=jet ? 0.0 : particle.y*6.283+particle.z*0.13;
    vec2 uv=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*(UV-0.5)+0.5;
    vec4 tex=texture(cloud,uv);
    float density=tex.r*tex.a;
    ALBEDO=tint.rgb*mix(0.7,1.4,tex.r);
    float border=smoothstep(0.0,0.12,UV.x)*smoothstep(1.0,0.88,UV.x)*smoothstep(0.0,0.12,UV.y)*smoothstep(1.0,0.88,UV.y);
    float depth=texture(scene_depth,SCREEN_UV).r;
    vec3 ndc=vec3(SCREEN_UV,depth)*2.0-1.0;
    vec4 scene=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
    float soft=smoothstep(0.0,0.65,VERTEX.z-scene.z/scene.w);
    ALPHA=density*tint.a*particle.x*border*soft;
}
