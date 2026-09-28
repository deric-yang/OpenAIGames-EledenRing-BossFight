class_name VitalBar
extends Control
## A real value plus a strictly visual, delayed damage trail.

var value := 1.0
var trail := 1.0
var hold_left := 0.0
var trail_age := 0.0
var delayed_damage := true
var fill_color := Color("852f2b")

func set_value(next: float, instant := false) -> void:
    next = clampf(next, 0.0, 1.0)
    if instant or next > value or not delayed_damage:
        trail = next
        hold_left = 0.0
        trail_age = 0.0
    elif next < value:
        hold_left = minf(1.0, maxf(0.0, 1.6 - trail_age))
    value = next
    queue_redraw()

func advance(delta: float) -> void:
    if trail > value:
        trail_age += delta
        var held := minf(delta, hold_left)
        hold_left = maxf(0.0, hold_left - delta)
        trail = move_toward(trail, value, (delta - held) * 0.65)
    else:
        trail_age = 0.0
    queue_redraw()

func _process(delta: float) -> void:
    advance(delta)

func _draw() -> void:
    var inner := Rect2(2, 3, maxf(0, size.x - 4), maxf(0, size.y - 6))
    draw_rect(Rect2(Vector2.ZERO, size), Color("141512"))
    draw_rect(Rect2(Vector2.ZERO, size), Color("776a48"), false, 1.0)
    draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)), Color("c9a56b"))
    draw_rect(Rect2(inner.position, Vector2(inner.size.x * value, inner.size.y)), fill_color)
    draw_line(Vector2(2, 3), Vector2(2 + inner.size.x * value, 3), fill_color.lightened(0.28), 1)
    # Deterministic stains remain inside the filled area and never obscure its endpoint.
    for i in range(70):
        var x := fmod(float(i * 73 + 19), maxf(1.0, inner.size.x))
        var y := 3.0 + fmod(float(i * 17), maxf(1.0, inner.size.y))
        if x < inner.size.x * value:
            draw_line(Vector2(x + 2, y), Vector2(minf(x + 6, inner.size.x * value + 2), y), Color(0.02, 0.02, 0.015, 0.23), 1)
    var center := Vector2(-12, size.y * 0.5)
    var gold := Color("b09a69")
    draw_polyline(PackedVector2Array([center + Vector2(-7, 0), center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)]), gold, 1, true)
    draw_line(center + Vector2(0, -11), center + Vector2(0, 11), gold, 1, true)
    draw_circle(center, 2, gold)
