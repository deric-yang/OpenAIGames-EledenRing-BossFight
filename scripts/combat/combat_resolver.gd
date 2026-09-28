class_name CombatResolver
extends RefCounted

static func in_range(attacker: Node3D, target: Node3D, radius: float) -> bool:
    var distance := attacker.position.distance_to(target.position)
    if attacker.is_inside_tree() and target.is_inside_tree():
        distance = attacker.global_position.distance_to(target.global_position)
    return distance <= radius

static func resolve_player_hit(attacker: Node3D, target: Node3D, radius: float) -> bool:
    return in_range(attacker, target, radius)

static func resolve_boss_hit(attacker: Node3D, target: Node3D, radius: float, rolling: bool) -> bool:
    if rolling:
        return false
    return in_range(attacker, target, radius)
