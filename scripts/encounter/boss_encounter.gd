class_name BossEncounter
extends Node

const RESPAWN_POSITION := Vector3(-8.0, 0.02, 7.0)

var event_bus: CombatEventBus
var phase_controller: PhaseController
var player: PlayerController
var boss: BossController
var camera_director: CameraDirector
var surface_feedback: SurfaceFeedback
var surface_query: SurfaceQuery
var stage := "intro"
var input_locked := true
var intro_left := 2.8
var execution_left := 0.0
var defeat_left := 0.0
var result := ""

func setup(bus: CombatEventBus, p: PlayerController, b: BossController, camera: CameraDirector, feedback: SurfaceFeedback, query: SurfaceQuery) -> void:
    event_bus = bus
    player = p
    boss = b
    camera_director = camera
    surface_feedback = feedback
    surface_query = query
    phase_controller = PhaseController.new()
    add_child(phase_controller)
    phase_controller.setup(bus)
    phase_controller.transition_started.connect(_on_transition_started)
    phase_controller.transition_finished.connect(_on_transition_finished)
    player.setup(self)
    boss.setup(self)
    reset()

func reset() -> void:
    stage = "intro"
    input_locked = true
    intro_left = 2.8
    execution_left = 0.0
    defeat_left = 0.0
    result = ""
    phase_controller.reset()
    player.reset_state()
    boss.reset_state()
    player.global_position = RESPAWN_POSITION
    boss.global_position = Vector3(5.4, 0.02, -2.0)
    if surface_feedback:
        surface_feedback.set_phase_two(false)
    player.facing = Vector3(
        boss.global_position.x - player.global_position.x,
        0.0,
        boss.global_position.z - player.global_position.z
    ).normalized()
    event_bus.reset()
    event_bus.emit_event("encounter_reset", {"phase": 1})

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("reset_encounter"):
        reset()
        return
    if stage == "intro":
        intro_left = maxf(0.0, intro_left - delta)
        if intro_left == 0.0:
            stage = "fight"
            input_locked = false
            event_bus.emit_event("intro_finished", {"phase": 1})
            event_bus.emit_event("phase_started", {"phase": 1})
    elif stage == "transition":
        input_locked = true
        if not phase_controller.transitioning:
            stage = "fight"
            input_locked = false
    elif stage == "execution":
        input_locked = true
        execution_left = maxf(0.0, execution_left - delta)
        if execution_left == 0.0:
            stage = "victory"
            result = "victory"
            event_bus.emit_event("victory", {"phase": 2})
    elif stage == "defeat":
        input_locked = true
        defeat_left = maxf(0.0, defeat_left - delta)
        if defeat_left == 0.0:
            result = "defeat"

func player_attack(origin: Vector3, direction: Vector3) -> void:
    if stage != "fight":
        return
    if CombatResolver.resolve_player_hit(player, boss, 2.25):
        boss.receive_hit(14.0 if phase_controller.phase == 1 else 17.0, 1)
    else:
        event_bus.emit_event("attack_miss", {"actor": "player", "world_position": origin, "direction": direction})

func boss_attack() -> void:
    if stage != "fight":
        return
    var hit := CombatResolver.resolve_boss_hit(boss, player, 3.15 if phase_controller.phase == 1 else 3.65, player.roll_left > 0.0)
    event_bus.emit_event("boss_landed", {"actor": "boss", "world_position": boss.global_position, "impact_tier": 2})
    if hit:
        player.receive_damage(18.0 if phase_controller.phase == 1 else 25.0)

func emit_step(actor: String, position: Vector3, heavy := false) -> void:
    var surface := surface_query.query(position) if surface_query else "sand"
    event_bus.emit_event("%s_step" % actor, {"actor": actor, "world_position": position, "surface_id": surface, "impact_tier": 2 if heavy else 1})
    if surface_feedback:
        surface_feedback.trigger_step(position, heavy, surface)

func open_execution() -> void:
    if stage != "fight":
        return
    stage = "execution"
    input_locked = true
    execution_left = 3.5
    event_bus.emit_event("execution_started", {"actor": "player", "target": "boss", "world_position": boss.global_position})

func defeat() -> void:
    if stage in ["defeat", "victory"]:
        return
    stage = "defeat"
    input_locked = true
    defeat_left = 1.2
    result = "defeat"
    event_bus.emit_event("player_died", {"actor": "player", "target": "boss"})

func _on_transition_started() -> void:
    stage = "transition"
    input_locked = true
    if surface_feedback:
        surface_feedback.set_phase_two(true)

func _on_transition_finished(new_phase: int) -> void:
    event_bus.emit_event("transition_finished", {"phase": new_phase})
