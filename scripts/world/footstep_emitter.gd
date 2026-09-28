class_name FootstepEmitter
extends Node

var surface_query: SurfaceQuery
var event_bus: CombatEventBus

func setup(query: SurfaceQuery, bus: CombatEventBus) -> void:
    surface_query = query
    event_bus = bus

func emit_step(actor: String, position: Vector3, heavy := false) -> void:
    if not surface_query or not event_bus:
        return
    var surface := surface_query.query(position)
    event_bus.emit_event("%s_step" % actor, {
        "actor": actor,
        "world_position": position,
        "surface_id": surface,
        "impact_tier": 2 if heavy else 1,
    })
