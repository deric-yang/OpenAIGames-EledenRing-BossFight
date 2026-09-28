shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform bool rune = false;
void fragment() {
    float weave=0.8+0.2*sin(UV.y*91.0+sin(UV.x*13.0));
    ALBEDO=rune?vec3(0.82,0.75,0.56):vec3(0.71,0.72,0.67);
    ALPHA=(rune?0.32:0.105)*weave;
    EMISSION=ALBEDO*(rune?0.23:0.03);
}
