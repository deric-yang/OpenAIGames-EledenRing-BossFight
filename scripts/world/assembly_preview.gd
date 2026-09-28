extends Node3D
## Static art assembly. No combat, player animation or final hand grip is implied.

const ROOT := "res://assets/runtime/assembly/"
var camera: Camera3D
var focus := Vector3(0, 3.8, -4)
var yaw := 0.2
var pitch := 0.06
var distance := 28.0
var rotating := false
var status: Label
var presets := [
    [Vector3(0, 3.8, -4), 0.16, 0.02, 28.0],
    [Vector3(-0.6, 3.8, -4), 0.27, 0.09, 13.5],
    [Vector3(-2.6, 3.15, -3.3), -0.5, 0.09, 4.2],
    [Vector3(0, 10, -32), 0.35, 0.5, 130.0],
    [Vector3(0.4, 0.65, 13), 0.3, 0.7, 7.0],
]

func _ready() -> void:
    seed(92703)
    _environment()
    var terrain := _asset("terrain", Vector3.ZERO)
    var sand := ShaderMaterial.new()
    sand.shader = load("res://shaders/world/assembly_sand.gdshader")
    for node in terrain.find_children("*", "MeshInstance3D", true, false):
        node.material_override = sand
    _asset("tree", Vector3(15, _height(15, -120) - 22, -120))
    _asset("boss", Vector3(0, _height(0, -4), -4))
    var player := _asset("player", Vector3(0.4, _height(0.4, 13), 13))
    player.rotation.y = PI
    var respawn := Node3D.new()
    respawn.set_script(load("res://scripts/world/golden_respawn.gd"))
    respawn.position = Vector3(0.4, _height(0.4, 13) + 0.02, 13)
    add_child(respawn)
    var mount := Node3D.new()
    mount.name = "RightHandGrip_StaticFit"
    mount.position = Vector3(-2.53, 3.04, -3.38)
    mount.rotation_degrees = Vector3(-7, 4, 13)
    add_child(mount)
    var sword := load(ROOT + "sword.glb").instantiate() as Node3D
    sword.position.y = -0.40
    mount.add_child(sword)
    _scatter()
    for data in [Vector3(-32, 21, -33), Vector3(35, 28, -57), Vector3(-60, 37, -87), Vector3(66, 45, -103), Vector3(3, 44, -75)]:
        var flag := _asset("standard", data)
        flag.rotation_degrees.y = randf_range(-30, 30)
        flag.scale = Vector3.ONE * randf_range(1.1, 1.9)
        for mesh in flag.find_children("*", "MeshInstance3D", true, false):
            mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        for animation_player in flag.find_children("*", "AnimationPlayer", true, false):
            var names: PackedStringArray = animation_player.get_animation_list()
            for anim_name in names:
                if anim_name != "RESET":
                    animation_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
                    animation_player.play(anim_name)
                    animation_player.seek(randf_range(0, 4))
                    break
    for position in [Vector3(-6, 0, 16), Vector3(-15, 0, -12), Vector3(19, 0, -27), Vector3(-27, 0, -42), Vector3(11, 0, 8), Vector3(33, 0, -57), Vector3(-44, 0, -70)]:
        var fire := RespawnBonfire.new()
        fire.include_sword = false
        fire.position = Vector3(position.x, _height(position.x, position.z), position.z)
        add_child(fire)
    camera = Camera3D.new()
    camera.fov = 62
    camera.far = 650
    camera.near = 0.08
    add_child(camera)
    _interface()
    _preset(0)

func _asset(id: String, position: Vector3) -> Node3D:
    var node := load(ROOT + id + ".glb").instantiate() as Node3D
    node.name = "Art_" + id
    node.position = position
    add_child(node)
    return node

func _scatter() -> void:
    var random := RandomNumberGenerator.new()
    random.seed = 92703
    for i in range(54):
        var angle := random.randf_range(0, TAU)
        var radius := random.randf_range(15, 83)
        var x := cos(angle) * radius
        var z := sin(angle) * radius - 19
        if absf(x) < 6 and z > -20 and z < 22:
            continue
        var kind: String = ["rubble", "graves", "polearms"][i % 3]
        var prop := _asset(kind, Vector3(x, _height(x, z) - 0.12, z))
        prop.rotation.y = random.randf_range(0, TAU)
        prop.scale = Vector3.ONE * random.randf_range(0.8, 1.4)

func _height(x: float, z: float) -> float:
    var y := -z
    var radius := Vector2(x * 0.96, y).length()
    var blend := smoothstep(30.0, 92.0, radius)
    var broad := 3.0 + 2.0 * sin(x * 0.035 + y * 0.013) + 1.5 * cos(y * 0.042 - x * 0.016)
    var ridges := 0.0
    for ridge in [Vector3(-125, 10, 15), Vector3(-75, 8, 13), Vector3(70, 9, 18), Vector3(125, 14, 22)]:
        var crest: float = x * 0.35 + ridge.x + 11 * sin(x * 0.023 + ridge.x)
        var delta := y - crest
        var width: float = ridge.z * (1.0 if delta < 0 else 2.4)
        ridges += ridge.y * exp(-pow(delta / width, 2))
    return 0.16 * sin(x * 0.07) * cos(y * 0.06) * (1 - blend) + (broad + ridges) * blend

func _environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/world/assembly_sky.gdshader")
    sky.sky_material = material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("acb0b7")
    environment.ambient_light_energy = 0.48
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color("847b6a")
    environment.fog_light_energy = 0.55
    environment.fog_density = 0.002
    environment.fog_sky_affect = 0.25
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-24, -35, 0)
    sun.light_color = Color("e4d6bd")
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 85
    add_child(sun)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0, 8, 8)
    fill.light_color = Color("c8d0d5")
    fill.light_energy = 2.4
    fill.omni_range = 24
    add_child(fill)

func _interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(24, 22)
    layer.add_child(panel)
    var box := VBoxContainer.new()
    var theme := Theme.new()
    theme.default_font = load("res://assets/runtime/fonts/WeepingDunesSerifSC.ttf")
    panel.theme = theme
    panel.add_child(box)
    var title := Label.new()
    title.text = "恸哭沙丘 · 场景装配 v03"
    title.add_theme_font_size_override("font_size", 22)
    box.add_child(title)
    var row := HBoxContainer.new()
    box.add_child(row)
    var labels := ["1 战场", "2 Boss", "3 握柄", "4 全景", "5 复活点"]
    for i in range(5):
        var button := Button.new()
        button.text = labels[i]
        button.pressed.connect(_preset.bind(i))
        row.add_child(button)
    status = Label.new()
    status.text = "右键拖动环绕 · 滚轮缩放\n静态尺寸装配；手指未握合，尚无战斗动画"
    box.add_child(status)

func _preset(index: int) -> void:
    focus = presets[index][0]
    yaw = presets[index][1]
    pitch = presets[index][2]
    distance = presets[index][3]
    _update_camera()

func _update_camera() -> void:
    camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_5:
        _preset(event.keycode - KEY_1)
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            rotating = event.pressed
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = maxf(1.1, distance * 0.9)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = minf(230, distance * 1.1)
        _update_camera()
    if event is InputEventMouseMotion and rotating:
        yaw -= event.relative.x * 0.006
        pitch = clampf(pitch + event.relative.y * 0.004, -0.18, 1.25)
        _update_camera()
