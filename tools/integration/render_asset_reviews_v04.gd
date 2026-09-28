extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    root.size = Vector2i(720,840)
    root.content_scale_size = Vector2i(720,840)
    var stage := Node3D.new()
    root.add_child(stage)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("3c3c3f")
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color.WHITE
    env.environment.ambient_light_energy = 0.7
    stage.add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40,-25,0)
    stage.add_child(light)
    var camera := Camera3D.new()
    camera.fov = 38
    camera.far = 2000
    stage.add_child(camera)
    var entries := {
        "silver_knight_v04_rigged":"characters/v04/knight.glb",
        "old_general_v04_rigged":"characters/v04/general.glb",
        "knight_longsword_v04":"characters/v04/knight_sword.glb",
        "banner_polearm_v04":"characters/v04/general_polearm.glb",
        "banner_cloth_v04":"characters/v04/banner_cloth.glb",
        "broken_war_bow_v04":"world/v04/broken_bow.glb",
        "fallen_soldier_relic_v04":"world/v04/fallen_soldier.glb",
        "dune_battlefield_v04":"world/v04/terrain.glb",
        "soul_standard_v04":"world/v04/standard.glb"}
    for id in entries:
        if not OS.get_cmdline_user_args().is_empty() and id != OS.get_cmdline_user_args()[0]: continue
        var model: Node3D = load("res://assets/runtime/"+entries[id]).instantiate()
        stage.add_child(model)
        var bounds := AABB()
        var first := true
        var triangles := 0
        for mesh in model.find_children("*","MeshInstance3D",true,false):
            var box: AABB = mesh.global_transform * mesh.get_aabb()
            bounds = box if first else bounds.merge(box)
            first = false
            triangles += mesh.mesh.get_faces().size()/3
        var center := bounds.get_center()
        var radius := bounds.size.length()*0.5
        var distance := radius/tan(deg_to_rad(camera.fov*0.5))*1.25
        var out: String = "res://assets/processed/"+id+"/review/"
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
        var names := ["front","three-quarter","back"]
        var angles := [0.0,0.7,PI]
        for i in names.size():
            var elevation := 0.6 if id == "dune_battlefield_v04" else 0.13
            camera.position = center+Vector3(sin(angles[i]),elevation,cos(angles[i])).normalized()*distance
            camera.look_at(center)
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(out+names[i]+".png")
        FileAccess.open(out+"inspection.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles":triangles,"armatures":model.find_children("*","Skeleton3D",true,false).size(),"source":entries[id]},"  "))
        model.free()
        print("ASSET_REVIEW_RENDERED ",id)
    quit()
