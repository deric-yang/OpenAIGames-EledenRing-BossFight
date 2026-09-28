extends SceneTree

var failures := 0
var checks := 0
var scene: Node3D
var camera: CameraDirector
var output := "res://qa/camera-v4"
var frames := []

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--qa-output="):
            output = argument.trim_prefix("--qa-output=")
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1280, 720)
    scene = load("res://scenes/boot.tscn").instantiate()
    root.add_child(scene)
    camera = scene.camera
    await _wait(90)
    await _capture("01-intro", true)
    await _wait(240)
    _check(not camera.intro, "intro exits naturally")
    _check(absf(scene.player.position.y) < 0.08, "player feet on floor")
    _check(absf(scene.boss.position.y) < 0.08, "boss feet on floor")
    await _capture("02-free-live", true)

    # Composition fixtures freeze combat, not camera/input/rendering.
    scene.encounter.set_process(false)
    scene.player.set_physics_process(false)
    scene.boss.set_physics_process(false)
    scene.player.global_position = Vector3(-5.8, 0.02, 5.0)
    scene.boss.global_position = Vector3(5.4, 0.02, -2.0)
    await _wait(120)
    _check_actor(scene.player, "free player")
    _check_actor(scene.boss, "free boss")
    await _capture("03-free-fixture")
    await _key(KEY_TAB)
    _check(camera.locked_on, "physical Tab locks target")
    await _wait(120)
    _check_actor(scene.player, "far lock player")
    _check_actor(scene.boss, "far lock boss")
    await _capture("04-locked-far")

    scene.player.global_position = Vector3(-2.0, 0.02, 3.2)
    scene.boss.global_position = Vector3(0.0, 0.02, 0.0)
    await _wait(150)
    _check_actor(scene.player, "close lock player")
    _check_actor(scene.boss, "close lock boss")
    _check((-camera.global_basis.z).y > 0.01, "close lock looks upward")
    await _capture("05-locked-near")
    await _key(KEY_TAB)
    _check(not camera.locked_on, "physical Tab unlocks target")
    await _wait(120)
    _check_actor(scene.player, "unlock player")
    await _capture("06-unlocked")

    var old_yaw := camera.orbit_yaw
    var right := InputEventKey.new()
    right.physical_keycode = KEY_RIGHT
    right.pressed = true
    Input.parse_input_event(right)
    await _wait(30)
    right.pressed = false
    Input.parse_input_event(right)
    await _wait(90)
    _check(absf(camera.orbit_yaw - old_yaw) > 0.1, "free orbit keyboard input")
    _check_actor(scene.player, "orbited player")
    await _capture("07-free-orbit")
    var mouse_yaw := camera.orbit_yaw
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_RIGHT
    mouse.pressed = true
    Input.parse_input_event(mouse)
    await _wait(3)
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(80.0, -10.0)
    Input.parse_input_event(motion)
    await _wait(3)
    mouse.pressed = false
    Input.parse_input_event(mouse)
    await _wait(90)
    _check(absf(camera.orbit_yaw - mouse_yaw) > 0.15, "right mouse drag orbits through HUD")
    _check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse release restores cursor")

    await _key(KEY_TAB)
    await _wait(120)
    var wall := StaticBody3D.new()
    wall.name = "QA_CameraBlocker"
    wall.collision_layer = 1
    var shape := BoxShape3D.new()
    shape.size = Vector3(8.0, 10.0, 0.4)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    wall.add_child(collision)
    scene.add_child(wall)
    var center := camera.focus.lerp(camera.global_position, 0.65)
    wall.global_transform = Transform3D(camera.global_basis, center)
    await _wait(90)
    _check(camera.collision_limited, "camera sweeps against world geometry")
    _check(camera.global_position.distance_to(camera.focus) < center.distance_to(camera.focus), "camera remains in front of blocker")
    wall.queue_free()
    await _wait(90)
    _check(not camera.collision_limited, "camera recovers after blocker removed")

    scene.player.global_position = Vector3(43.0, 0.02, 36.0)
    scene.boss.global_position = Vector3(35.0, 0.02, 28.0)
    await _wait(180)
    _check(camera.global_position.y >= 0.6, "boundary camera stays above ground")
    _check_actor(scene.player, "boundary player")
    _check_actor(scene.boss, "boundary boss")
    await _capture("08-boundary")
    root.size = Vector2i(960, 720)
    await _wait(120)
    _check_actor(scene.player, "4:3 player")
    _check_actor(scene.boss, "4:3 boss")
    await _capture("08b-four-three", true)
    root.size = Vector2i(1280, 720)
    await _wait(90)
    scene.surface_feedback.set_phase_two(true)
    scene.encounter.reset()
    await _wait(3)
    _check(camera.intro and not camera.locked_on, "reset clears camera lock")
    _check(not scene.surface_feedback.phase_two, "reset clears phase surface")
    await _capture("09-reset", true)

    var report := {"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "frames": frames}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    scene.free()
    await process_frame
    print("CAMERA_REVIEW_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
    quit(0 if failures == 0 else 1)

func _wait(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _key(code: Key) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = true
    Input.parse_input_event(event)
    await _wait(3)
    event.pressed = false
    Input.parse_input_event(event)
    await _wait(3)

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: %s" % label)

func _actor_rect(actor: Node3D) -> Rect2:
    var viewport_size := root.get_visible_rect().size
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for point in camera.framing_points(actor):
        var screen := camera.unproject_position(point) / viewport_size
        low = low.min(screen)
        high = high.max(screen)
    return Rect2(low, high - low)

func _check_actor(actor: Node3D, label: String) -> void:
    var rect := _actor_rect(actor)
    var safe := rect.position.x >= 0.04 and rect.end.x <= 0.96 and rect.position.y >= 0.09 and rect.end.y <= 0.87
    for point in camera.framing_points(actor):
        safe = safe and not camera.is_position_behind(point)
    _check(safe, "%s within screen safe region: %s" % [label, rect])

func _capture(label: String, show_location := false) -> void:
    if show_location:
        scene.hud.show_location("恸哭沙丘", "风暴遗迹战场")
        await _wait(45)
    var player_rect := _actor_rect(scene.player)
    var boss_rect := _actor_rect(scene.boss)
    frames.append({
        "name": label,
        "locked": camera.locked_on,
        "intro": camera.intro,
        "fov": camera.fov,
        "camera": str(camera.global_position),
        "focus": str(camera.focus),
        "collision_limited": camera.collision_limited,
        "player_screen": str(player_rect),
        "boss_screen": str(boss_rect),
        "combat_frozen": not scene.boss.is_physics_processing(),
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
    })
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
        var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
        _check(error == OK, "screenshot saved: " + label)
