class_name DuneHeightV04
extends RefCounted
const RESPAWN_CENTER := Vector2(7,-26)
const RESPAWN_FLAT_RADIUS := 3.1
const RESPAWN_BLEND_RADIUS := 7.5
static func sample(x: float, z: float) -> float:
    var original := unmodified(x,z)
    var distance := Vector2(x,z).distance_to(RESPAWN_CENTER)
    var weight := 1.0-smoothstep(RESPAWN_FLAT_RADIUS,RESPAWN_BLEND_RADIUS,distance)
    return lerpf(original,unmodified(RESPAWN_CENTER.x,RESPAWN_CENTER.y),weight)

static func unmodified(x: float, z: float) -> float:
    var y := -z
    var radius := Vector2(x * 0.96, y).length()
    var blend := smoothstep(30.0, 92.0, radius)
    var broad := 3.0 + 2.0 * sin(x * 0.035 + y * 0.013) + 1.5 * cos(y * 0.042 - x * 0.016)
    var ridges := 0.0
    for data in [Vector3(-125, 10, 15), Vector3(-75, 8, 13), Vector3(70, 9, 18), Vector3(125, 14, 22)]:
        var crest: float = x * 0.35 + data.x + 11.0 * sin(x * 0.023 + data.x)
        var distance: float = y - crest
        var width: float = data.z * (1.0 if distance < 0.0 else 2.4)
        ridges += data.y * exp(-pow(distance / width, 2))
    var center := 1.7 * sin(x * 0.075 + y * 0.045) + 0.8 * cos(y * 0.13 - x * 0.04)
    center += 0.35 * sin(x * 0.21 + y * 0.09)
    var old := lerpf(center, broad + ridges, blend)
    var ascent := smoothstep(-12.0,45.0,y)
    var sides := 1.0-smoothstep(42.0,110.0,absf(x-8.0))
    var rear := 1.0-smoothstep(130.0,178.0,y)
    var summit := 24.0*ascent*sides*rear
    var arena := 1.0-smoothstep(15.0,37.0,Vector2(x-8.0,y-68.0).length())
    var plateau := 2.0+0.45*sin(x*0.06)+0.35*cos(y*0.08)
    return lerpf(old,plateau,arena)+summit
