class_name BattleCamera
extends Camera3D
var game: Node3D
var locked_on := true
var intro := true
var yaw := 0.0
var pitch := 0.18
var shake := 0.0 # Compatibility with legacy review tools; runtime uses bounded impulses.
var shake_left := 0.0
var shake_duration := 0.1
var shake_strength := 0.0
var shake_offset := Vector3.ZERO
var shake_clock := 0.0
var blur_rect: ColorRect
var blur_material: ShaderMaterial
var blur_left := 0.0
var blur_duration := 0.13
var blur_strength := 0.0
var blur_origin := Vector3.ZERO
func _ready() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 19
    add_child(layer)
    blur_rect = ColorRect.new()
    blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(blur_rect)
    blur_material = ShaderMaterial.new()
    blur_material.shader = preload("res://shaders/vfx/impact_radial.gdshader")
    blur_rect.material = blur_material
    blur_rect.hide()
func impact_blur(origin: Vector3, power: float) -> void:
    blur_origin = origin
    blur_left = blur_duration
    blur_strength = clampf(power,0.0,0.018)
func tick_blur(delta: float) -> void:
    blur_left = maxf(0.0,blur_left-delta)
    blur_rect.visible = blur_left>0 and not is_position_behind(blur_origin)
    if not blur_rect.visible: return
    blur_material.set_shader_parameter("center",unproject_position(blur_origin)/get_viewport().get_visible_rect().size)
    blur_material.set_shader_parameter("strength",blur_strength*pow(blur_left/blur_duration,2.0))
func impulse(strength: float, duration: float) -> void:
    shake_strength = maxf(strength,shake_strength if shake_left>0 else 0)
    shake_duration = clampf(duration,0.05,0.15)
    shake_left = shake_duration
    shake_clock = 0
var execution_weight := 0.0
var executing := false
var review_camera := false
var review_distance := 16.0
var execution_yaw := 0.0
var hand_focus := Vector3.ZERO
func reset_execution() -> void:
    executing = false
    global_position -= shake_offset
    shake_offset = Vector3.ZERO
    shake_left = 0
    execution_weight = 0
    fov = 62
    blur_left = 0
    if blur_rect: blur_rect.hide()
func begin_execution() -> void:
    executing = true
    execution_yaw = game.player.rotation.y
    hand_focus = game.player.avatar.bone_transform("hand.R").origin
func end_execution() -> void:
    executing = false
func _unhandled_input(event: InputEvent) -> void:
    if executing: return
    if review_camera and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: review_distance = maxf(5,review_distance-0.8)
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: review_distance = minf(26,review_distance+0.8)
    if event.is_action_pressed("lock_on"): locked_on = not locked_on
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
        yaw -= event.relative.x * 0.004
        pitch = clampf(pitch + event.relative.y * 0.003,-0.10,0.65)
func _process(delta: float) -> void:
    if not game or not game.player: return
    tick_blur(delta)
    global_position -= shake_offset
    shake_offset = Vector3.ZERO
    if review_camera:
        var center: Vector3 = game.boss.global_position+Vector3.UP*3.3
        global_position = center+Vector3(sin(yaw)*review_distance,2+pitch*4,cos(yaw)*review_distance)
        look_at(center)
        fov = 52
        return
    var player: Vector3 = game.player.global_position
    var boss: Vector3 = game.boss.global_position
    var direction := boss - player
    direction.y = 0
    if locked_on and direction.length() > 1.2:
        yaw = lerp_angle(yaw,atan2(direction.x,direction.z),1-exp(-delta*3.0))
    var toward := Vector3(sin(yaw),0,cos(yaw))
    var focus := player + Vector3.UP * 2.45
    if locked_on: focus += toward * minf(direction.length()*0.22,3.0)
    var desired := player - toward * 5.8 + Vector3.UP * (2.7 + pitch*2.5)
    execution_weight = move_toward(execution_weight,1.0 if executing else 0.0,delta*(2.5 if executing else 1.5))
    if execution_weight > 0:
        var arm: Vector3 = game.player.avatar.bone_transform("hand.R").origin
        var shoulder: Vector3 = game.player.avatar.bone_transform("upper_arm.R").origin
        hand_focus = hand_focus.lerp(arm,1-exp(-delta*10))
        var local_arm: Vector3 = game.player.global_basis.inverse()*(arm-shoulder)
        var arm_turn := clampf(atan2(local_arm.x,maxf(0.2,local_arm.z))*0.3,-0.32,0.32)
        var progress := clampf(game.player.time/maxf(game.player.duration,0.001),0,1)
        var orbit := execution_yaw + 0.82 + sin(progress*PI)*0.3 + arm_turn
        var execution_focus := (player+Vector3.UP*1.25).lerp(hand_focus,0.48)
        var execution_position := execution_focus - Vector3(sin(orbit),0,cos(orbit))*(4.4-0.45*sin(progress*PI)) + Vector3.UP*0.8
        focus = focus.lerp(execution_focus,execution_weight)
        desired = desired.lerp(execution_position,execution_weight)
    fov = lerpf(62,53,execution_weight)
    desired.y = maxf(desired.y,DuneHeightV04.sample(desired.x,desired.z)+0.65)
    var query := PhysicsRayQueryParameters3D.create(focus,desired,1)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty(): desired = hit.position + hit.normal*0.45
    global_position = global_position.lerp(desired,1-exp(-delta*7)) if global_position != Vector3.ZERO else desired
    look_at(focus)
    if shake_left > 0:
        shake_clock += delta
        shake_left = maxf(0,shake_left-delta)
        var envelope := pow(shake_left/shake_duration,1.5)
        shake_offset = global_basis * Vector3(sin(shake_clock*190),cos(shake_clock*157)*0.65,0)*shake_strength*envelope
        global_position += shake_offset
