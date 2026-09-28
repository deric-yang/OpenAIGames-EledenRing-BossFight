extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var scene := Node3D.new()
    root.add_child(scene)
    var model = load("res://assets/runtime/characters/v04/knight_animated.scn").instantiate()
    scene.add_child(model)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(0.22,0.22,0.22)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color.WHITE
    env.environment.ambient_light_energy=0.8
    scene.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-35,45,0)
    scene.add_child(light)
    var cam := Camera3D.new()
    scene.add_child(cam)
    cam.current=true
    for side in [-1,1]:
        cam.position=Vector3(side*2.5,1.1,0)
        cam.look_at(Vector3(0,0.95,0))
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v06/cape-final-%d.png"%side))
    quit()
