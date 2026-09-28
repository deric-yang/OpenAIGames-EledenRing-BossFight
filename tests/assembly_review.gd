extends SceneTree

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var scene = load("res://scenes/assembly_preview.tscn").instantiate()
    root.add_child(scene)
    DirAccess.make_dir_recursive_absolute("res://qa/assembly-v03")
    if not scene.camera:
        push_error("Assembly failed to initialize")
        quit(1)
        return
    for i in range(5):
        scene._preset(i)
        for frame in range(20):
            await process_frame
        if DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://qa/assembly-v03/view-%d.png" % i)
    print("ASSEMBLY_REVIEW_COMPLETE")
    quit()
