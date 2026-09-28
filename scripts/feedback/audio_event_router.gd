class_name AudioEventRouter
extends Node

var last_event := ""
var event_count := 0

func setup(bus: CombatEventBus) -> void:
    bus.event_emitted.connect(_on_event)

func _on_event(event: Dictionary) -> void:
    last_event = str(event.get("type", ""))
    event_count += 1
    # Whitebox intentionally has no external audio dependency yet.
    # This is the stable routing boundary for later licensed SFX.
