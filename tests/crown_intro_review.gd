extends SceneTree
var game: Node3D
const OUT := "res://qa/crown-intro-v01/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.player.position = game.world.ground(8, -41)
    game.player.face(game.boss.position)
    game.boss.face(game.player.position)
    game.crown_intro.start()
    game.crown_intro.set_process(false)
    var info := {}
    for entry in [[1.35,"01-crown"],[3.6,"02-general"],[6.1,"03-sand"],[7.8,"03-empty-hands"],[8.65,"04-battlefield"],[9.4,"05-fade"]]:
        game.crown_intro.sample(entry[0])
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+entry[1]+".png"))
        info[entry[1]] = {"time":entry[0],"hand_errors":str(game.crown_intro.hand_errors),"camera":str(game.crown_intro.camera.global_position),"head":str(game.crown_intro.anchor.affine_inverse()*game.boss.avatar.bone_transform("head").origin),"hand":str(game.crown_intro.anchor.affine_inverse()*game.boss.avatar.bone_transform("hand.R").origin)}
    FileAccess.open(OUT+"review.json",FileAccess.WRITE).store_string(JSON.stringify(info,"  "))
    print("CROWN_INTRO_REVIEW ", JSON.stringify(info))
    game.queue_free()
    await process_frame
    quit()
