shader_type canvas_item;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center = vec2(0.5);
uniform float strength = 0.0;
void fragment() {
    vec2 direction=SCREEN_UV-center;
    float mask=smoothstep(0.06,0.22,length(direction))*(1.0-smoothstep(0.48,0.75,length(direction)));
    vec4 color=texture(scene,SCREEN_UV)*0.28;
    for(int i=1;i<=4;i++) {
        color+=texture(scene,SCREEN_UV-direction*strength*mask*float(i))*0.18;
    }
    COLOR=vec4(color.rgb,1.0);
}
