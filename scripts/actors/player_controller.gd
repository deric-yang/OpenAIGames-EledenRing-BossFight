class_name PlayerController
extends CharacterBody3D

var encounter: BossEncounter
var speed := 5.2
var sprint_speed := 8.0
var hp := 100.0
var max_hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var stamina_recovery_left := 0.0
var sprint_exhausted := false
var attack_left := 0.0
var attack_time := 0.0
var attack_hit := false
var roll_left := 0.0
var step_left := 0.0
var facing := Vector3.FORWARD

func setup(owner: BossEncounter) -> void:
    encounter = owner

func reset_state() -> void:
    hp = max_hp
    stamina = max_stamina
    stamina_recovery_left = 0.0
    sprint_exhausted = false
    attack_left = 0.0
    attack_time = 0.0
    attack_hit = false
    roll_left = 0.0
    step_left = 0.0
    velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
    if not encounter or encounter.input_locked:
        velocity = Vector3.ZERO
        return
    attack_left = maxf(0.0, attack_left - delta)
    recover_stamina(delta)
    if roll_left > 0.0:
        roll_left = maxf(0.0, roll_left - delta)
        velocity.x = facing.x * 10.0
        velocity.z = facing.z * 10.0
        _move_grounded(delta)
        return
    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var camera := encounter.camera_director
    var direction := camera.global_basis.x * input.x + camera.global_basis.z * input.y
    direction.y = 0.0
    var sprinting := Input.is_action_pressed("sprint") and not sprint_exhausted and direction.length_squared() > 0.01
    if sprinting and not spend_stamina(18.0 * delta):
        sprinting = false
        sprint_exhausted = true
    if not Input.is_action_pressed("sprint") and stamina >= 15.0:
        sprint_exhausted = false
    if direction.length_squared() > 0.01:
        facing = direction.normalized()
        rotation.y = atan2(-facing.x, -facing.z)
        var move_speed := sprint_speed if sprinting else speed
        velocity.x = facing.x * move_speed
        velocity.z = facing.z * move_speed
        step_left -= delta
        if step_left <= 0.0:
            encounter.emit_step("player", global_position)
            step_left = 0.28 if sprinting else 0.42
    else:
        velocity.x = 0.0
        velocity.z = 0.0
    _move_grounded(delta)
    if Input.is_action_just_pressed("roll") and spend_stamina(26.0):
        roll_left = 0.32
        attack_left = 0.0
        attack_hit = false
        encounter.event_bus.emit_event("player_roll", {"actor": "player", "world_position": global_position})
    if Input.is_action_just_pressed("attack") and attack_left <= 0.0 and roll_left <= 0.0 and spend_stamina(18.0):
        attack_left = 0.55
        attack_time = 0.0
        attack_hit = false
        encounter.event_bus.emit_event("attack_started", {"actor": "player", "world_position": global_position})
    if attack_left > 0.0:
        attack_time += delta
        if not attack_hit and attack_time >= 0.16 and attack_time <= 0.34:
            attack_hit = true
            encounter.player_attack(global_position + facing * 1.1, facing)

func spend_stamina(amount: float) -> bool:
    if stamina < amount:
        return false
    stamina = maxf(0.0, stamina - amount)
    stamina_recovery_left = 0.65
    return true

func recover_stamina(delta: float) -> void:
    var held := minf(delta, stamina_recovery_left)
    stamina_recovery_left = maxf(0.0, stamina_recovery_left - delta)
    if roll_left <= 0.0 and attack_left <= 0.0:
        stamina = minf(max_stamina, stamina + (delta - held) * 28.0)

func _move_grounded(delta: float) -> void:
    velocity.y -= 22.0 * delta
    move_and_slide()
    global_position.x = clampf(global_position.x, -48.0, 48.0)
    global_position.z = clampf(global_position.z, -43.0, 43.0)

func receive_damage(amount: float) -> void:
    if roll_left > 0.0:
        encounter.event_bus.emit_event("evade", {"actor": "player", "world_position": global_position})
        return
    hp = maxf(0.0, hp - amount)
    encounter.event_bus.emit_event("player_hit", {"actor": "boss", "target": "player", "world_position": global_position, "impact_tier": 2})
    if hp <= 0.0:
        encounter.defeat()
