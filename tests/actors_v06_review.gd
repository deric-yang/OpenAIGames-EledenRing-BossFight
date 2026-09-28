extends SceneTree
var game: Node3D
var out := "res://qa/iteration-v06/"
func _initialize() -> void: call_deferred("run")
func shot(file: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out+file+".png"))
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    game.stage = "review"
    game.effects.clear()
    game.hud.root.visible = false
    game.player.avatar.model.visible = false
    game.player.weapon.visible = false
    game.boss.face(game.boss.global_position+Vector3(0,0,1))
    game.camera_director.set_process(false)
    var camera: Camera3D = game.camera_director
    var base: Vector3 = game.boss.global_position
    camera.position = base+Vector3(10,6,13)
    camera.look_at(base+Vector3.UP*3.2)
    game.boss.avatar.play_clip("Warden_Kneel_Hold",false,1,0)
    game.boss.avatar.tick(0.1)
    game.boss.weapon.tick(0.1)
    game.boss.eyes.tick(0.1)
    await shot("kneel")
    game.boss.avatar.play_clip("Sword_Idle",false,1,0)
    game.boss.avatar.tick(0.1)
    game.boss.weapon.tick(0.1)
    game.boss.eyes.tick(0.1)
    var head: Vector3 = game.boss.avatar.bone_transform("head").origin
    camera.position = head+Vector3(1,0.8,3)
    camera.look_at(head+Vector3.UP*0.35)
    await shot("eyes")
    game.player.avatar.model.visible = true
    game.player.weapon.visible = true
    game.player.global_position = base+Vector3(0,0,2.5)
    game.player.global_position.y = DuneHeightV04.sample(game.player.position.x,game.player.position.z)
    game.boss.stagger_left = 5
    game.stage = "fight"
    game.execute()
    game.player.avatar.blend_left = 0
    game.player.avatar.elapsed = game.player.duration*0.40
    game.player.avatar.tick(0.016)
    game.player.time = game.player.duration*0.40
    game.player.weapon.tick(0.016)
    game.boss.avatar.tick(0.3)
    game.boss.weapon.tick(0.3)
    for i in 60: camera._process(1.0/60)
    game._physics_process(0.001)
    game.effects._process(0.14)
    await shot("execution")
    game.hud.root.visible = true
    game.event_bus.emit_event("player_died",{})
    game.hud._process(1.4)
    await shot("you-died")
    game.hud.root.visible = false
    game.stage = "explore"
    game.player.action("ual2/Sword_Regular_A","attack",[0.4])
    game.player.avatar.blend_left = 0
    game.player.trail.set_process(false)
    game.player.trail.clear()
    for fraction in [0.25,0.29,0.33,0.37,0.40]:
        game.player.time = game.player.duration*fraction
        game.player.avatar.elapsed = game.player.time
        game.player.avatar.tick(0)
        game.player.weapon.tick(0.016)
        game.player.trail._process(0.016)
    await shot("weapon-trail")
    print("V05_VISUAL_REVIEW_DONE")
    quit()
