class_name CameraDirector
extends Camera3D

var player: Node3D
var boss: Node3D
var event_bus: CombatEventBus
var shake := 0.0
var default_fov := 56.0
var fov_kick := 0.0
var locked_on := false
var intro := true
var orbit_yaw := 0.0
var orbit_pitch := 0.22
var focus := Vector3.ZERO
var collision_limited := false
var _snap_next := true
var _orbit_dragging := false
var _player_bounds := AABB()
var _boss_bounds := AABB()
var _camera_shape := SphereShape3D.new()

func setup(p: Node3D, b: Node3D, bus: CombatEventBus) -> void:
    player = p
    boss = b
    event_bus = bus
    current = true
    near = 0.15
    far = 240.0
    fov = default_fov
    process_physics_priority = 10
    _camera_shape.radius = 0.3
    _player_bounds = _visual_bounds(player)
    _boss_bounds = _visual_bounds(boss)
    _reset_orbit()
    bus.event_emitted.connect(_on_event)

func _visual_bounds(actor: Node3D) -> AABB:
    var bounds := AABB()
    var initialized := false
    for child in actor.find_children("*", "MeshInstance3D", true, false):
        var mesh := child as MeshInstance3D
        var local_bounds: AABB = (actor.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
        bounds = bounds.merge(local_bounds) if initialized else local_bounds
        initialized = true
    return bounds

func framing_points(actor: Node3D) -> PackedVector3Array:
    var bounds := _player_bounds if actor == player else _boss_bounds
    var points := PackedVector3Array()
    for index in range(8):
        points.append(actor.global_transform * bounds.get_endpoint(index))
    return points

func _reset_orbit() -> void:
    var forward := player.global_position.direction_to(Vector3(0.0, player.global_position.y, -16.0))
    orbit_yaw = atan2(forward.x, forward.z)
    orbit_pitch = 0.22
    _snap_next = true
    _release_mouse()

func set_locked(active: bool) -> void:
    active = active and not intro and is_instance_valid(boss)
    if active == locked_on:
        return
    locked_on = active
    if not active:
        var forward := -global_basis.z
        orbit_yaw = atan2(forward.x, forward.z)
        orbit_pitch = clampf(asin(global_basis.z.y), -0.12, 0.48)
    _release_mouse()
    event_bus.emit_event("camera_lock_changed", {"locked": locked_on})

func _release_mouse() -> void:
    if _orbit_dragging:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _orbit_dragging = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _release_mouse()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        _orbit_dragging = event.pressed and not intro and not locked_on
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _orbit_dragging else Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseMotion and _orbit_dragging:
        orbit_yaw -= event.relative.x * 0.003
        orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.003, -0.12, 0.48)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_mouse()

func _on_event(event: Dictionary) -> void:
    var kind := str(event.get("type", ""))
    if kind in ["hit", "player_hit", "boss_landed"]:
        shake = maxf(shake, 0.08 if event.get("impact_tier", 1) < 2 else 0.18)
        fov_kick = maxf(fov_kick, 2.0 if kind != "boss_landed" else 4.0)
    elif kind == "phase_transition_started":
        shake = 0.26
        fov_kick = 6.0
    elif kind == "execution_started":
        shake = 0.16
        fov_kick = 5.0
    elif kind == "encounter_reset":
        set_locked(false)
        intro = true
        fov_kick = 0.0
        shake = 0.0
        _reset_orbit()
    elif kind == "intro_finished":
        intro = false

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        _release_mouse()
        return
    if locked_on and not is_instance_valid(boss):
        set_locked(false)
    if Input.is_action_just_pressed("lock_on") and not intro:
        set_locked(not locked_on)
    if not intro and not locked_on:
        var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
        orbit_yaw += turn * delta * 1.6

    var target: Vector3
    var desired: Vector3
    var points := framing_points(player)
    if intro:
        target = Vector3(0.0, 8.5, -16.0)
        desired = Vector3(12.0, 9.0, 33.0)
    elif locked_on:
        var direction := boss.global_position - player.global_position
        direction.y = 0.0
        var separation := direction.length()
        direction = direction.normalized() if separation > 0.1 else Vector3(sin(orbit_yaw), 0.0, cos(orbit_yaw))
        var player_focus := player.global_position + Vector3.UP * 0.95
        var boss_focus := boss.global_position + Vector3.UP * (_boss_bounds.end.y * 0.52)
        target = player_focus.lerp(boss_focus, 0.58)
        var pitch := lerpf(-0.08, 0.15, clampf((separation - 3.0) / 12.0, 0.0, 1.0))
        var back := (-direction * cos(pitch) + Vector3.UP * sin(pitch) + direction.cross(Vector3.UP) * 0.2).normalized()
        points.append_array(framing_points(boss))
        desired = target + back * _fit_distance(target, back, points, 8.5)
    else:
        var direction := Vector3(sin(orbit_yaw), 0.0, cos(orbit_yaw))
        target = player.global_position + Vector3.UP * 1.65 + direction * 2.8
        var back := -direction * cos(orbit_pitch) + Vector3.UP * sin(orbit_pitch)
        if is_instance_valid(boss):
            var to_boss := boss.global_position - player.global_position
            to_boss.y = 0.0
            if to_boss.length() < 20.0 and to_boss.normalized().dot(direction) > 0.55:
                points.append_array(framing_points(boss))
        desired = target + back * _fit_distance(target, back, points, 10.5)

    var weight := 1.0 if _snap_next else 1.0 - exp(-delta * 5.0)
    focus = focus.lerp(target, weight)
    var next_position := global_position.lerp(desired, weight)
    if not intro:
        var back := (next_position - focus).normalized()
        var safe_distance := _fit_distance(focus, back, points, next_position.distance_to(focus))
        next_position = focus + back * safe_distance
        next_position = _avoid_obstacles(focus, next_position)
    global_position = next_position
    _snap_next = false
    var jitter := Vector3.ZERO
    if shake > 0.001:
        jitter = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
    look_at(focus + jitter, Vector3.UP)
    shake = move_toward(shake, 0.0, delta * 1.8)
    fov_kick = move_toward(fov_kick, 0.0, delta * 10.0)
    fov = default_fov + fov_kick

func _fit_distance(target: Vector3, back: Vector3, points: PackedVector3Array, minimum: float) -> float:
    var frame := Basis.looking_at(-back, Vector3.UP)
    var viewport_size := get_viewport().get_visible_rect().size
    var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
    var tan_vertical := tan(deg_to_rad(default_fov * 0.5))
    var distance := minimum
    for point in points:
        var local := frame.transposed() * (point - target)
        var horizontal := absf(local.x) / (tan_vertical * aspect * 0.78)
        var vertical := absf(local.y) / (tan_vertical * (0.70 if local.y > 0.0 else 0.62))
        distance = maxf(distance, local.z + maxf(horizontal, vertical) + 0.35)
    return distance

func _avoid_obstacles(target: Vector3, desired: Vector3) -> Vector3:
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _camera_shape
    query.transform = Transform3D(Basis.IDENTITY, target)
    query.motion = desired - target
    query.collision_mask = 1
    var fractions := get_world_3d().direct_space_state.cast_motion(query)
    collision_limited = fractions[0] < 1.0
    var result := target + query.motion * fractions[0]
    result.y = maxf(result.y, 0.6)
    return result
