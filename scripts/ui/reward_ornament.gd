class_name RewardOrnament
extends Control
## Resolution-independent engraved frame, corner leaves and central crest.
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    var gold := Color("aa8a50",0.85)
    var faded := Color("8f774c",0.32)
    var w := size.x
    var h := size.y
    draw_rect(Rect2(Vector2.ZERO,size),Color("100f0c",0.96))
    draw_rect(Rect2(Vector2(4,4),size-Vector2(8,8)),gold,false,1,true)
    draw_rect(Rect2(Vector2(9,9),size-Vector2(18,18)),faded,false,1,true)
    # A dim seal behind the icon, with engraved rather than luminous line work.
    var center := Vector2(w*0.16,h*0.50)
    var radius := h*0.36
    draw_circle(center,radius,Color("675130",0.12))
    draw_arc(center,radius,0,TAU,72,faded,1,true)
    draw_arc(center,radius-4,0,TAU,72,faded,1,true)
    for i in 16:
        var angle := i*TAU/16.0
        var normal := Vector2(cos(angle),sin(angle))
        draw_line(center+normal*(radius-1),center+normal*(radius-5),faded,1,true)
    for corner in [Vector2(0,0),Vector2(w,0),Vector2(0,h),Vector2(w,h)]:
        var direction := Vector2(1 if corner.x==0 else -1,1 if corner.y==0 else -1)
        var points := PackedVector2Array()
        for point in [Vector2(7,29),Vector2(13,19),Vector2(13,13),Vector2(19,13),Vector2(29,7)]:
            points.append(corner+point*direction)
        draw_polyline(points,gold,1.2,true)
        for i in 3:
            var anchor: Vector2 = corner+Vector2(19+i*8,17)*direction
            var leaf := PackedVector2Array([anchor,anchor+Vector2(7,2)*direction,
                anchor+Vector2(11,7)*direction,anchor+Vector2(3,5)*direction,anchor])
            draw_polyline(leaf,faded,1,true)
        draw_circle(corner+Vector2(11,11)*direction,1.7,gold)
    for y in [4.0,h-4]:
        var crest := PackedVector2Array([Vector2(w*.5-17,y),Vector2(w*.5-7,y-3),
            Vector2(w*.5,y-7),Vector2(w*.5+7,y-3),Vector2(w*.5+17,y),
            Vector2(w*.5+7,y+3),Vector2(w*.5,y+7),Vector2(w*.5-7,y+3),Vector2(w*.5-17,y)])
        draw_colored_polygon(crest,Color("17140e"))
        draw_polyline(crest,gold,1,true)
    draw_line(Vector2(w*.34,h*.35),Vector2(w*.87,h*.35),faded,1,true)
    draw_line(Vector2(w*.34,h*.77),Vector2(w*.87,h*.77),faded,1,true)
