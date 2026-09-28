class_name CombatEventBus
extends Node

signal event_emitted(event: Dictionary)

var _sequence := 0
var encounter_id := "gilded-ruin-whitebox"

func emit_event(kind: String, data: Dictionary = {}) -> Dictionary:
    _sequence += 1
    var event := {
        "event_id": _sequence,
        "encounter_id": encounter_id,
        "combat_time": Time.get_ticks_msec() / 1000.0,
        "type": kind,
    }
    event.merge(data)
    event_emitted.emit(event)
    return event

func reset() -> void:
    _sequence = 0
