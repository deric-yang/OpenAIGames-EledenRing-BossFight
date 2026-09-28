extends Node3D

var event_bus: CombatEventBus
var encounter: BossEncounter
var player: PlayerController
var boss: BossController
var surface_feedback: SurfaceFeedback
var scenery: DunesScenery
var camera: CameraDirector
var hud: EncounterHUD

func _ready() -> void:
    var legacy_assembly := OS.get_cmdline_user_args().has("--assembly-v03")
    if OS.has_feature("web"):
        legacy_assembly = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('assembly-v03')"))
    if legacy_assembly:
        get_tree().change_scene_to_file.call_deferred("res://scenes/assembly_preview.tscn")
        return
    var assembly_preview := OS.get_cmdline_user_args().has("--assembly-preview")
    if OS.has_feature("web"):
        assembly_preview = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('assembly')"))
    if assembly_preview:
        get_tree().change_scene_to_file.call_deferred("res://scenes/assembly_v04.tscn")
        return
    var ui_preview := OS.get_cmdline_user_args().has("--ui-preview")
    if OS.has_feature("web"):
        ui_preview = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('ui')"))
    if ui_preview:
        get_tree().change_scene_to_file.call_deferred("res://scenes/ui_preview.tscn")
        return
    if not OS.get_cmdline_user_args().has("--legacy-whitebox"):
        get_tree().change_scene_to_file.call_deferred("res://scenes/playable_v04.tscn")
        return
    _build_environment()
    scenery = DunesScenery.new()
    scenery.name = "DunesScenery"
    add_child(scenery)
    scenery.build()
    event_bus = CombatEventBus.new()
    event_bus.name = "CombatEventBus"
    add_child(event_bus)
    var audio := AudioEventRouter.new()
    audio.name = "AudioEventRouter"
    add_child(audio)
    audio.setup(event_bus)
    var surface_query := SurfaceQuery.new()
    surface_query.name = "SurfaceQuery"
    add_child(surface_query)
    surface_query.setup(Vector3(0.0, 0.0, 1.0), Vector2(5.5, 3.0))
    _build_arena()
    player = _build_player()
    boss = _build_boss()
    camera = CameraDirector.new()
    camera.name = "CameraDirector"
    add_child(camera)
    encounter = BossEncounter.new()
    encounter.name = "BossEncounter"
    add_child(encounter)
    encounter.setup(event_bus, player, boss, camera, surface_feedback, surface_query)
    camera.setup(player, boss, event_bus)
    hud = EncounterHUD.new()
    hud.name = "EncounterHUD"
    add_child(hud)
    hud.setup(encounter, event_bus)
    var bonfire := RespawnBonfire.new()
    bonfire.name = "RespawnBonfire_Procedural"
    bonfire.position = BossEncounter.RESPAWN_POSITION + Vector3(1.4, 0, 0)
    add_child(bonfire)

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    world.name = "WorldEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("110a12")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("5f4657")
    environment.ambient_light_energy = 0.62
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color("4b3848")
    environment.fog_light_energy = 0.48
    environment.fog_density = 0.006
    environment.fog_height = 2.0
    environment.fog_height_density = 0.035
    environment.fog_depth_begin = 24.0
    environment.fog_depth_end = 92.0
    world.environment = environment
    add_child(world)

    var moon := DirectionalLight3D.new()
    moon.name = "DirectionalLight3D_Moon"
    moon.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
    moon.light_color = Color("a9a6c4")
    moon.light_energy = 1.15
    moon.shadow_enabled = true
    add_child(moon)

    for data in [
        {"name": "TorchLight_West", "position": Vector3(-12.0, 3.2, 1.0)},
        {"name": "TorchLight_East", "position": Vector3(12.0, 3.2, -1.0)},
        {"name": "RiftLight", "position": Vector3(0.0, 12.0, -42.0)}
    ]:
        var light := OmniLight3D.new()
        light.name = data.name
        light.position = data.position
        light.light_color = Color("d47743") if data.name != "RiftLight" else Color("e9b84b")
        light.light_energy = 4.5 if data.name != "RiftLight" else 2.2
        light.omni_range = 14.0 if data.name != "RiftLight" else 22.0
        light.shadow_enabled = data.name != "RiftLight"
        add_child(light)

func _build_arena() -> void:
    # DunesScenery owns the rolling terrain, core, ruins, flags and distant tree.
    # Keep the gameplay boundary separate so the camera can ignore collision layer 4.
    for side in [-1.0, 1.0]:
        _solid_box("OuterBoundaryX_%s" % side, Vector3(side * 49.0, 4.0, 0.0), Vector3(1.0, 8.0, 88.0)).collision_layer = 4
        _solid_box("OuterBoundaryZ_%s" % side, Vector3(0.0, 4.0, side * 44.0), Vector3(100.0, 8.0, 1.0)).collision_layer = 4

    var wet_sand := _mesh_box("WetSandPatch", Vector3(0.0, 0.005, 1.0), Vector3(11.0, 0.008, 6.0), Color("49363a"), 0.05, 0.42)
    surface_feedback = SurfaceFeedback.new()
    surface_feedback.name = "ArenaSurfaceFeedback"
    add_child(surface_feedback)
    surface_feedback.setup(wet_sand)

    _build_torches()

func _build_torches() -> void:
    # Keep warm readability on the perimeter; never place a tall torch inside the lock-on lane.
    var torch_positions := [
        Vector3(-16.0, 1.25, -8.0),
        Vector3(16.0, 1.25, -6.0),
        Vector3(-15.0, 1.25, 10.0)
    ]
    for i in range(torch_positions.size()):
        var post := MeshInstance3D.new()
        post.name = "TorchPost_%02d" % i
        var post_mesh := CylinderMesh.new()
        post_mesh.top_radius = 0.12
        post_mesh.bottom_radius = 0.17
        post_mesh.height = 2.5
        post_mesh.radial_segments = 8
        post.mesh = post_mesh
        post.position = torch_positions[i]
        post.material_override = _material(Color("38282b"), 0.45, 0.52)
        add_child(post)

        var flame := MeshInstance3D.new()
        flame.name = "TorchFlame_%02d" % i
        var flame_mesh := SphereMesh.new()
        flame_mesh.radius = 0.32
        flame_mesh.height = 0.8
        flame_mesh.radial_segments = 8
        flame_mesh.rings = 4
        flame.mesh = flame_mesh
        flame.position = post.position + Vector3(0.0, 1.45, 0.0)
        flame.material_override = _material(Color("d85b32"), 0.0, 0.34, Color("ff954a"), 1.15)
        add_child(flame)

func _build_player() -> PlayerController:
    var actor := PlayerController.new()
    actor.name = "Player"
    add_child(actor)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    body.mesh = capsule
    body.position.y = 0.9
    body.material_override = _material(Color("929b9f"), 0.7, 0.52)
    actor.add_child(body)
    _add_collision(actor, 0.42, 1.8)
    var blade := MeshInstance3D.new()
    blade.name = "PlayerWeaponPlaceholder"
    var blade_mesh := BoxMesh.new()
    blade_mesh.size = Vector3(0.12, 1.6, 0.08)
    blade.mesh = blade_mesh
    blade.position = Vector3(0.62, 1.0, -0.1)
    blade.rotation_degrees = Vector3(0.0, 0.0, -22.0)
    blade.material_override = _material(Color("b9bec9"), 0.8, 0.25)
    actor.add_child(blade)
    return actor

func _build_boss() -> BossController:
    var actor := BossController.new()
    actor.name = "BossBlockout"
    add_child(actor)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 1.35
    capsule.height = 5.4
    body.mesh = capsule
    body.position.y = 2.7
    body.material_override = _material(Color("403239"), 0.55, 0.56, Color("7d3029"), 0.8)
    actor.add_child(body)
    var head := MeshInstance3D.new()
    var head_mesh := BoxMesh.new()
    head_mesh.size = Vector3(1.35, 0.95, 1.05)
    head.mesh = head_mesh
    head.position = Vector3(0.0, 5.8, -0.05)
    head.material_override = _material(Color("201b22"), 0.7, 0.3)
    actor.add_child(head)
    _add_collision(actor, 1.35, 5.4)
    return actor

func _add_collision(actor: CharacterBody3D, radius: float, height: float) -> void:
    actor.collision_layer = 2
    actor.collision_mask = 7
    actor.floor_snap_length = 0.25
    var shape_node := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = radius
    shape.height = height
    shape_node.shape = shape
    shape_node.position.y = height * 0.5
    actor.add_child(shape_node)

func _solid_box(label: String, position: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = label
    body.position = position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _mesh_box(label: String, position: Vector3, size: Vector3, color: Color, metallic := 0.0, roughness := 0.86) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _material(color, metallic, roughness)
    add_child(mesh_instance)
    return mesh_instance

func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, emission_energy := 1.8) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    if emission != Color.BLACK:
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = emission_energy
    return material
