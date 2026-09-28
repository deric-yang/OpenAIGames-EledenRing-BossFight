extends SceneTree
var stage: Node3D
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    stage = Node3D.new()
    root.add_child(stage)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("49494b")
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color.WHITE
    env.environment.ambient_light_energy = 0.65
    stage.add_child(env)
    var light := DirectionalLight3D.new()
    stage.add_child(light)
    light.rotation_degrees = Vector3(-45, -25, 0)
    var camera := Camera3D.new()
    stage.add_child(camera)
    camera.position = Vector3(0, 1.35, 2.8)
    camera.fov = 45
    camera.look_at(Vector3(0, 0.95, 0))
    var avatar = load("res://scripts/animation/duel_avatar.gd").new()
    stage.add_child(avatar)
    avatar.setup("general")
    print("TARGET_TRANSFORM ", avatar.rig.global_transform)
    avatar.play_clip("combat-master-38cb716005f9f62f42ec")
    print("BAKED ", avatar.baked, " CLIP ", avatar.animation.current_animation)
    for j in 40:
        avatar.tick(1.0 / 60.0)
        await process_frame
    print("POSE ", avatar.bone_transform("hips").origin, " ", avatar.bone_transform("foot.L").origin)
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/characters-v04"))
        root.get_texture().get_image().save_png("res://qa/characters-v04/general-roar.png")
    print("CHARACTER_V04_REVIEW_COMPLETE")
    quit()
