class_name SurfaceQuery
extends Node

var wet_sand_center := Vector3(0.0, 0.0, 1.0)
var wet_sand_extents := Vector2(5.5, 3.0)
var battlefield_extents := Vector2(15.5, 11.5)

func setup(center: Vector3, extents: Vector2) -> void:
    wet_sand_center = center
    wet_sand_extents = extents

func query(position: Vector3) -> String:
    var local := position - wet_sand_center
    if absf(local.x) <= wet_sand_extents.x and absf(local.z) <= wet_sand_extents.y:
        return "wet_sand"
    if absf(position.x) <= battlefield_extents.x and absf(position.z) <= battlefield_extents.y:
        return "ruin_stone"
    return "sand"
