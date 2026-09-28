class_name BossController
extends CharacterBody3D

var encounter: BossEncounter
var max_hp := 100.0
var hp := 100.0
var attack_left := 1.8
var attack_time := 0.0
var attack_active := false
var attack_hit := false
var step_left := 0.0
var phase := 1
var stagger_left := 0.0

func setup(owner: BossEncounter) -> void:
    encounter = owner

func reset_state() -> void:
    hp = max_hp
    phase = 1
    attack_left = 1.8
    attack_time = 0.0
    attack_active = false
    attack_hit = false
    stagger_left = 0.0
    velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
    if not encounter or encounter.input_locked or encounter.stage != "fight":
        velocity = Vector3.ZERO
        return
    phase = encounter.phase_controller.phase
    stagger_left = maxf(0.0, stagger_left - delta)
    var to_player: Vector3 = encounter.player.global_position - global_position
    to_player.y = 0.0
    var distance := to_player.length()
    if distance > 3.8 and stagger_left <= 0.0:
        var pursuit := to_player.normalized() * (1.2 if phase == 1 else 1.6)
        velocity.x = pursuit.x
        velocity.z = pursuit.z
        step_left -= delta
        if step_left <= 0.0:
            encounter.emit_step("boss", global_position, true)
            step_left = 0.78 if phase == 1 else 0.58
    else:
        velocity.x = 0.0
        velocity.z = 0.0
    velocity.y -= 22.0 * delta
    move_and_slide()
    attack_left = maxf(0.0, attack_left - delta)
    if attack_left <= 0.0 and stagger_left <= 0.0:
        attack_left = 2.4 if phase == 1 else 1.55
        attack_time = 0.0
        attack_active = true
        attack_hit = false
        encounter.event_bus.emit_event("attack_started", {"actor": "boss", "phase": phase, "world_position": global_position})
    if attack_active:
        attack_time += delta
        var active_time := 0.48 if phase == 1 else 0.34
        if not attack_hit and attack_time >= active_time and attack_time <= active_time + 0.18:
            attack_hit = true
            encounter.boss_attack()
        if attack_time >= 0.88 if phase == 1 else attack_time >= 0.68:
            attack_active = false

func receive_hit(amount: float, impact: int) -> void:
    if encounter.stage != "fight":
        return
    hp = maxf(0.0, hp - amount)
    stagger_left = 0.22 if impact < 2 else 0.42
    encounter.event_bus.emit_event("hit", {"actor": "player", "target": "boss", "world_position": global_position + Vector3.UP * 1.8, "impact_tier": impact, "hp": hp})
    encounter.phase_controller.evaluate_boss_hp(hp)
    if hp <= 0.0:
        encounter.open_execution()
