extends SceneTree
const OUT := "res://qa/crown-continuity-20260928/"
var game: Node3D
var report := {}

func _initialize() -> void: call_deferred("run")

func capture(label: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+label+".png"))
    report[label] = {"stage":game.stage,"state":game.boss.state,"head":str(game.boss.avatar.bone_transform("head").origin),"hp":game.player.hp}

func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    for i in 240: game._physics_process(1.0/60)
    game.hud.location_time = 0
    game.hud._process(0)
    game.camera_director._process(1)
    game.camera_director.set_process(false)
    await capture("01-spawn")
    var camera: Camera3D = game.camera_director
    var anchor: Transform3D = game.boss.global_transform
    camera.global_position = anchor*Vector3(9,5,15)
    camera.look_at(anchor*Vector3(0,3.4,0))
    await capture("02-waiting-kneel")
    game.crown_intro.start()
    game.crown_intro.set_process(false)
    game.crown_intro.sample(1.2)
    await capture("03-cinematic-crown")
    game.crown_intro.sample(10)
    game.crown_intro.advance(0.01)
    game.crown_intro.advance(0.46)
    camera.global_position = anchor*Vector3(9,5,15)
    camera.look_at(anchor*Vector3(0,3.4,0))
    await capture("04-rise-start")
    var duration: float = game.boss.duration
    for i in ceili(duration*30): game._physics_process(1.0/60)
    await capture("05-rise-middle")
    for i in ceili(duration*30)+2: game._physics_process(1.0/60)
    await capture("06-standing")
    FileAccess.open(OUT+"review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    game.queue_free()
    await process_frame
    quit()
