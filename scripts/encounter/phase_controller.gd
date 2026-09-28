class_name PhaseController
extends Node

signal phase_started(phase: int)
signal transition_started()
signal transition_finished(phase: int)

var phase := 1
var transitioning := false
var transition_left := 0.0
var threshold := 50.0
var event_bus: CombatEventBus

func setup(bus: CombatEventBus) -> void:
    event_bus = bus

func reset() -> void:
    phase = 1
    transitioning = false
    transition_left = 0.0

func evaluate_boss_hp(hp: float) -> void:
    if phase == 1 and not transitioning and hp <= threshold:
        begin_transition()

func begin_transition() -> void:
    transitioning = true
    transition_left = 3.2
    transition_started.emit()
    if event_bus:
        event_bus.emit_event("phase_transition_started", {"from_phase": 1, "to_phase": 2})

func _process(delta: float) -> void:
    if not transitioning:
        return
    transition_left = maxf(0.0, transition_left - delta)
    if transition_left == 0.0:
        transitioning = false
        phase = 2
        phase_started.emit(phase)
        transition_finished.emit(phase)
        if event_bus:
            event_bus.emit_event("phase_started", {"phase": phase})
