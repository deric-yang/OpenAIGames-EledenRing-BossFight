shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color;
uniform vec4 base_color : source_color = vec4(1.0);
void fragment() {
    vec3 stone = texture(albedo_tex,UV).rgb * base_color.rgb;
    float gold = smoothstep(0.12,0.30,stone.r-stone.b) * smoothstep(0.08,0.22,stone.g-stone.b);
    gold *= smoothstep(0.26,0.58,max(stone.r,stone.g));
    ALBEDO = stone;
    ROUGHNESS = 0.8;
    METALLIC = gold * 0.35;
    EMISSION = vec3(1.0,0.58,0.12)*gold*(1.25+0.12*sin(TIME*0.7+VERTEX.y));
}
