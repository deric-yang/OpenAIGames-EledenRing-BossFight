extends Node3D
## Ten-second real-time sequence; no gameplay clock or actor motion advances while active.
signal completed(was_skipped: bool)
const CrownProp = preload("res://scripts/cinematic/crown_prop.gd")
const DURATION := 10.0
const HOLD_SECONDS := 0.8
const SKIP_FADE := 0.3
const RETURN_FADE := 0.45
var game: Node3D
var active := false
var waiting := false
var elapsed := 0.0
var hold_time := 0.0
var escape_down := false
var skip_time := -1.0
var returning := false
var return_time := 0.0
var was_skipped := false
var handed_off := false
var played := false
var focused := true
var shot_index := 0
var camera: Camera3D
var prop: Node3D
var stage_root: Node3D
var canvas: CanvasLayer
var overlay: ColorRect
var top_bar: ColorRect
var bottom_bar: ColorRect
var hint: Label
var progress: ProgressBar
var anchor := Transform3D.IDENTITY
var kneel_pose: Array[Transform3D] = []
var upright_pose: Array[Transform3D] = []
var saved_player := Transform3D.IDENTITY
var saved_boss := Transform3D.IDENTITY
var saved_camera_input := true
var saved_camera_process := true
var old_hud_visible := true
var hand_errors := Vector2.ZERO
var sand_audio: AudioStreamPlayer
var grade: ColorRect
var rendered_frames := 0
var playback_seconds := 0.0

func setup(owner_game: Node3D) -> void:
    game = owner_game
    camera = Camera3D.new()
    camera.name = "CrownIntroCamera"
    camera.near = 0.08
    camera.far = 650
    add_child(camera)
    canvas = CanvasLayer.new()
    canvas.layer = 90
    add_child(canvas)
    grade = ColorRect.new()
    grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var grade_material := ShaderMaterial.new()
    grade_material.shader = preload("res://shaders/cinematic/grade.gdshader")
    grade.material = grade_material
    canvas.add_child(grade)
    grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    top_bar = ColorRect.new()
    top_bar.color = Color.BLACK
    canvas.add_child(top_bar)
    top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_bar.anchor_bottom = 0.11
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_bar = ColorRect.new()
    bottom_bar.color = Color.BLACK
    canvas.add_child(bottom_bar)
    bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_bar.anchor_top = 0.89
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint = Label.new()
    hint.text = "HOLD ESC TO SKIP"
    hint.add_theme_font_override("font", load("res://assets/runtime/fonts/CormorantGaramond.ttf"))
    hint.add_theme_font_size_override("font_size", 19)
    hint.add_theme_color_override("font_color", Color("c1b59b"))
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    bottom_bar.add_child(hint)
    hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hint.offset_right = -35
    hint.offset_top = 12
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress = ProgressBar.new()
    progress.show_percentage = false
    progress.max_value = HOLD_SECONDS
    bottom_bar.add_child(progress)
    progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    progress.offset_left = -174
    progress.offset_right = -35
    progress.offset_top = 42
    progress.offset_bottom = 45
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("b6a271")
    progress.add_theme_stylebox_override("fill", fill)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color("28251f")
    progress.add_theme_stylebox_override("background", bg)
    overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas.hide()
    set_process(false)

func start() -> void:
    if active or game.review_dashboard: return
    # Use exactly the same prop and hand pose that the player saw while approaching.
    if not waiting or not anchor.is_equal_approx(game.boss.global_transform):
        prepare_waiting()
    waiting = false
    prop.grains.show()
    active = true
    elapsed = 0.0
    hold_time = 0.0
    escape_down = false
    skip_time = -1.0
    returning = false
    return_time = 0.0
    was_skipped = false
    handed_off = false
    focused = true
    rendered_frames = 0
    playback_seconds = 0.0
    saved_player = game.player.global_transform
    saved_boss = game.boss.global_transform
    old_hud_visible = game.hud.root.visible
    saved_camera_input = game.camera_director.is_processing_unhandled_input()
    saved_camera_process = game.camera_director.is_processing()
    game.stage = "cinematic"
    game.shared_hitstop = 0.0
    game.pending_contacts.clear()
    game.hazards.clear()
    game.effects.clear()
    game.skill_fx.clear()
    game.audio.set_combat(false)
    game.player.velocity = Vector3.ZERO
    game.boss.velocity = Vector3.ZERO
    game.player.idle()
    game.player.avatar.model.hide()
    game.player.weapon.hide()
    game.boss.weapon.hide()
    game.player.trail.clear()
    game.boss.trail.clear()
    game.hud.root.hide()
    game.camera_director.reset_execution()
    game.camera_director.set_process(false)
    game.camera_director.set_process_unhandled_input(false)
    sand_audio = AudioStreamPlayer.new()
    sand_audio.stream = load("res://assets/runtime/audio/v04/player_steps_loop_0.wav").duplicate()
    if sand_audio.stream is AudioStreamWAV: sand_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    sand_audio.pitch_scale = 1.18
    sand_audio.volume_db = -60
    stage_root.add_child(sand_audio)
    if game.audio.ambient: sand_audio.play()
    canvas.show()
    grade.show()
    hint.show()
    progress.value = 0
    camera.make_current()
    sample(0.0)
    set_process(true)

func prepare_waiting() -> void:
    clear_set()
    waiting = true
    game.boss.velocity = Vector3.ZERO
    game.boss.idle()
    game.boss.avatar.blend_left = 0.0
    game.boss.avatar.tick(0.0)
    upright_pose.clear()
    for i in game.boss.avatar.rig.get_bone_count():
        upright_pose.append(game.boss.avatar.rig.get_bone_pose(i))
    game.boss.action("Warden_Kneel_Hold", "ceremony")
    game.boss.avatar.blend_left = 0.0
    game.boss.avatar.tick(0.1)
    kneel_pose.clear()
    for i in game.boss.avatar.rig.get_bone_count():
        kneel_pose.append(game.boss.avatar.rig.get_bone_pose(i))
    anchor = game.boss.global_transform
    game.boss.weapon.hide()
    game.boss.trail.clear()
    stage_root = Node3D.new()
    stage_root.name = "CrownIntroSet"
    add_child(stage_root)
    prop = CrownProp.new()
    stage_root.add_child(prop)
    prop.prepare(anchor * Transform3D(Basis.IDENTITY, Vector3(0, 3.06, 1.88)))
    var weapon := game.boss.weapon.duplicate() as Node3D
    weapon.name = "PlantedPolearm"
    stage_root.add_child(weapon)
    weapon.show()
    # Match the existing large weapon scale; rest its butt on the arena dune.
    var weapon_point := anchor * Vector3(-2.35, 0, 0.15)
    weapon_point.y = DuneHeightV04.sample(weapon_point.x, weapon_point.z) + 4.12
    weapon.global_transform = Transform3D(anchor.basis * Basis(Vector3.FORWARD, 0.08) * Basis.from_scale(Vector3.ONE * 4.324325), weapon_point)
    var key := OmniLight3D.new()
    key.light_color = Color("ffd5a0")
    key.light_energy = 0.8
    key.omni_range = 13
    key.omni_attenuation = 0.9
    stage_root.add_child(key)
    key.global_position = anchor * Vector3(3.5, 7.0, 4.0)
    prop.sample(0.0)
    prop.grains.hide()
    pose_hands(0.0)
    if game.boss.eyes:
        game.boss.eyes.attachment.hide()
        game.boss.eyes.history.clear()
        game.boss.eyes.streak.clear_surfaces()

func clear_set() -> void:
    if is_instance_valid(stage_root):
        stage_root.hide()
        stage_root.queue_free()
    stage_root = null
    prop = null
    sand_audio = null

func cancel_waiting() -> void:
    # Developer motion-review / free-combat shortcuts bypass the ceremony deliberately.
    if not waiting: return
    waiting = false
    clear_set()
    game.boss.idle()
    game.boss.avatar.blend_left = 0
    game.boss.avatar.tick(0)
    game.boss.weapon.tick(0)
    game.boss.weapon.show()
    if game.boss.eyes: game.boss.eyes.attachment.show()

func world_point(local: Vector3) -> Vector3:
    return anchor * local

func _process(delta: float) -> void:
    if not active or not focused: return
    rendered_frames += 1
    playback_seconds += delta
    advance(minf(delta, 0.1))

func advance(delta: float) -> void:
    if not active: return
    if returning:
        return_time += delta
        overlay.color.a = 1.0 - smoothstep(0.0, RETURN_FADE, return_time)
        top_bar.modulate.a = overlay.color.a
        bottom_bar.modulate.a = overlay.color.a
        if return_time >= RETURN_FADE: finish()
        return
    if skip_time >= 0:
        skip_time += delta
        overlay.color.a = maxf(overlay.color.a, smoothstep(0.0, SKIP_FADE, skip_time))
        if skip_time >= SKIP_FADE: handoff()
        return
    if escape_down:
        hold_time += delta
        if hold_time >= HOLD_SECONDS:
            was_skipped = true
            skip_time = 0.0
    else:
        hold_time = 0.0
    progress.value = minf(hold_time, HOLD_SECONDS)
    elapsed = minf(DURATION, elapsed + delta)
    if game.dialogue: game.dialogue.crown_tick(elapsed)
    sample(elapsed)
    if elapsed >= DURATION: handoff()

func sample(time: float) -> void:
    elapsed = clampf(time, 0.0, DURATION)
    prop.sample(elapsed)
    pose_hands(elapsed)
    if game.boss.eyes:
        game.boss.eyes.tick(0.0)
        # The battle glow returns on the head lift; no red trail across the prop.
        game.boss.eyes.attachment.visible = elapsed > 7.65
        game.boss.eyes.history.clear()
        game.boss.eyes.streak.clear_surfaces()
    var crown_center: Vector3 = prop.crown.global_transform * Vector3(0, 0.33, 0)
    var head: Vector3 = game.boss.avatar.bone_transform("head").origin
    var position_at: Vector3
    var target: Vector3
    if elapsed < 2.0:
        shot_index = 0
        camera.fov = 31
        position_at = crown_center + anchor.basis * Vector3(1.9 - elapsed * 0.06, 0.78, 4.4 - elapsed * 0.13)
        target = crown_center - Vector3.UP * 0.16
    elif elapsed < 5.0:
        shot_index = 1
        var f := (elapsed - 2.0) / 3.0
        camera.fov = 35
        position_at = world_point(Vector3(3.7 - f * 0.30, 4.8, 8.0 - f * 0.25))
        target = head.lerp(crown_center, 0.50)
    elif elapsed < 8.4:
        shot_index = 2
        var f := (elapsed - 5.0) / 3.4
        camera.fov = 43
        position_at = world_point(Vector3(8.0 + f * 0.5, 3.5, 13.0 + f * 0.6))
        target = world_point(Vector3(0, 2.6, 0.2))
    else:
        shot_index = 3
        camera.fov = 56
        position_at = world_point(Vector3(14.0, 7.0, 20.0))
        target = world_point(Vector3(0, 7.3, -14.0))
    camera.global_position = position_at
    camera.look_at(target)
    overlay.color.a = maxf(1.0 - smoothstep(0.0, 0.3, elapsed), smoothstep(8.8, 10.0, elapsed))
    top_bar.modulate.a = 1
    bottom_bar.modulate.a = 1
    if sand_audio:
        var gain := smoothstep(0.7, 2.0, elapsed) * (1.0 - smoothstep(5.8, 7.8, elapsed))
        sand_audio.volume_db = linear_to_db(maxf(0.0001, gain * 0.12))

func position_of(key: String) -> Vector3:
    return game.boss.avatar.bone_transform(key).origin

func aim_bone(key: String, child: String, target: Vector3) -> void:
    var avatar: DuelAvatar = game.boss.avatar
    var id: int = avatar.target_bones[key]
    var from := position_of(child) - position_of(key)
    var to := target - position_of(key)
    var desired := Basis(Quaternion(from.normalized(), to.normalized())) * avatar.bone_transform(key).basis.orthonormalized()
    var parent := avatar.rig.get_bone_parent(id)
    var parent_basis := avatar.rig.global_basis * avatar.rig.get_bone_global_pose(parent).basis
    avatar.rig.set_bone_pose_rotation(id, (parent_basis.inverse() * desired).orthonormalized().get_rotation_quaternion())
    avatar.rig.force_update_all_bone_transforms()

func arm(side: String, wrist: Vector3, pole: Vector3) -> void:
    var a := "upper_arm." + side
    var b := "forearm." + side
    var c := "hand." + side
    var start := position_of(a)
    var upper := start.distance_to(position_of(b))
    var lower := position_of(b).distance_to(position_of(c))
    var axis := (wrist - start).normalized()
    var distance := clampf(start.distance_to(wrist), absf(upper - lower) + 0.001, upper + lower - 0.001)
    var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
    var bend := (pole - start - axis * (pole - start).dot(axis)).normalized()
    aim_bone(a, b, start + axis * along + bend * sqrt(maxf(0.0, upper * upper - along * along)))
    aim_bone(b, c, wrist)
    var avatar: DuelAvatar = game.boss.avatar
    var id: int = avatar.target_bones[c]
    # Open fingers from the target rig's own rest pose; the palms support the lower band.
    for i in avatar.rig.get_bone_count():
        var name: String = avatar.rig.get_bone_name(i)
        if name.ends_with("." + side) and ("f_" in name or "thumb" in name):
            avatar.rig.set_bone_pose_rotation(i, avatar.rig.get_bone_rest(i).basis.get_rotation_quaternion())
    avatar.rig.force_update_all_bone_transforms()
    var sign := 1.0 if side == "L" else -1.0
    var finger_dir := (anchor.basis * Vector3(-sign * 0.65, 0.22, 0.72)).normalized()
    var up := Vector3.UP
    var x := finger_dir.cross(up).normalized()
    var desired := Basis(x, finger_dir, x.cross(finger_dir))
    var parent := avatar.rig.get_bone_parent(id)
    var parent_basis := avatar.rig.global_basis * avatar.rig.get_bone_global_pose(parent).basis
    avatar.rig.set_bone_pose_rotation(id, (parent_basis.inverse() * desired).orthonormalized().get_rotation_quaternion())
    avatar.rig.force_update_all_bone_transforms()

func pose_hands(time: float) -> void:
    var avatar: DuelAvatar = game.boss.avatar
    for i in kneel_pose.size(): avatar.rig.set_bone_pose(i, kneel_pose[i])
    # The execution hold bows deeply. Preserve its planted legs but raise the torso
    # to make the ceremonial prop, hands and face readable in the close shots.
    var spine: int = avatar.target_bones["spine.001"]
    for i in upright_pose.size():
        var ancestor := i
        while ancestor >= 0:
            if ancestor == spine:
                avatar.rig.set_bone_pose(i, upright_pose[i])
                break
            ancestor = avatar.rig.get_bone_parent(ancestor)
    avatar.rig.force_update_all_bone_transforms()
    var lift := smoothstep(7.5, 8.3, time)
    aim_bone("neck", "head", position_of("head") + anchor.basis * Vector3(0, 0.035 * lift, -0.13 * lift))
    var frame: Transform3D = prop.transform_at(time)
    var left := frame * Vector3(0.94, -0.10, -0.10)
    var right := frame * Vector3(-0.94, -0.10, -0.10)
    arm("L", left, world_point(Vector3(2.0, 2.6, 0.4)))
    arm("R", right, world_point(Vector3(-2.0, 2.6, 0.4)))
    hand_errors = Vector2(position_of("hand.L").distance_to(left), position_of("hand.R").distance_to(right))

func _input(event: InputEvent) -> void:
    if not active: return
    if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
        if not event.echo:
            escape_down = event.pressed
            if not event.pressed: hold_time = 0.0
        get_viewport().set_input_as_handled()
    elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
        if event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed:
            game.audio.start_ambient()
            if sand_audio and not sand_audio.playing and not returning: sand_audio.play()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        focused = false
        escape_down = false
        hold_time = 0.0
        if progress: progress.value = 0
        if sand_audio: sand_audio.stream_paused = true
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        focused = true
        if sand_audio: sand_audio.stream_paused = false

func handoff() -> void:
    if handed_off: return
    if game.dialogue: game.dialogue.end_cinematic(was_skipped)
    handed_off = true
    returning = true
    return_time = 0.0
    overlay.color.a = 1.0
    grade.hide()
    hint.hide()
    progress.value = 0
    restore_actors(true)
    clear_set()
    game.camera_director.make_current()
    game.camera_director.set_process(saved_camera_process)
    # Snap behind the restored player while completely black, then fade in.
    game.camera_director.global_position = Vector3.ZERO
    game.camera_director.yaw = game.player.rotation.y
    game.camera_director._process(1.0)
    game.hud.root.visible = old_hud_visible

func restore_actors(keep_boss_kneeling: bool = false) -> void:
    game.player.global_transform = saved_player
    game.boss.global_transform = saved_boss
    game.player.velocity = Vector3.ZERO
    game.boss.velocity = Vector3.ZERO
    game.player.queued = false
    game.boss.stagger_left = 0
    for actor in [game.player, game.boss]:
        actor.avatar.model.show()
        if actor == game.boss and keep_boss_kneeling:
            # Keep the final empty-handed kneel through the black handoff and fade-in.
            pose_hands(8.4)
            actor.weapon.hide()
            if actor.eyes: actor.eyes.attachment.show()
            continue
        actor.idle()
        actor.avatar.blend_left = 0
        actor.avatar.tick(0)
        actor.weapon.tick(0)
        actor.weapon.show()
        actor.trail.clear()
        if actor.eyes:
            actor.eyes.attachment.show()
            actor.eyes.tick(0.0)

func finish() -> void:
    if not active: return
    active = false
    played = true
    set_process(false)
    canvas.hide()
    game.camera_director.set_process_unhandled_input(saved_camera_input)
    game.stage = "explore" if game.crown_preview else "fight"
    game.boss.face(game.player.global_position)
    game.boss.action(game.STANDUP, "getup", [], 0.85)
    if game.dialogue: game.dialogue.say("challenge", true)
    game.boss.avatar.blend_left = 0.35
    game.boss.avatar.tick(0.0)
    game.boss.weapon.tick(0.0)
    game.boss.weapon.show()
    game.ai_wait = game.boss.duration + 0.35
    game.audio.set_combat(not game.crown_preview, false)
    if rendered_frames > 0:
        print("CROWN_INTRO_FINISHED ", JSON.stringify({"skipped":was_skipped,"seconds":playback_seconds,"mean_fps":rendered_frames / maxf(playback_seconds,0.001),"review":game.crown_preview}))
    completed.emit(was_skipped)

func abort() -> void:
    if not active: return
    if game.dialogue: game.dialogue.end_cinematic(true)
    active = false
    set_process(false)
    escape_down = false
    hold_time = 0
    restore_actors()
    clear_set()
    canvas.hide()
    game.hud.root.visible = old_hud_visible
    game.camera_director.make_current()
    game.camera_director.set_process(saved_camera_process)
    game.camera_director.set_process_unhandled_input(saved_camera_input)

func reset_sequence() -> void:
    abort()
    waiting = false
    clear_set()
    played = false
    elapsed = 0.0
