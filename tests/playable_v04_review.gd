extends SceneTree
var game: Node3D
func _initialize() -> void:
    call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame
func shot(name: String) -> void:
    if DisplayServer.get_name() == "headless": return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://qa/playable-v04/"+name+".png")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/playable-v04"))
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    await frames(220)
    game.stage = "review"
    game.boss.idle()
    await shot("01-spawn")
    var placements := FileAccess.open("res://qa/playable-v04/placements.json",FileAccess.WRITE)
    placements.store_string(JSON.stringify(game.world.placements,"  "))
    FileAccess.open("res://qa/playable-v04/fragments.json",FileAccess.WRITE).store_string(JSON.stringify(game.world.fragment_placements))
    game.player.global_position = game.world.ground(0,0)
    game.player.face(game.boss.global_position)
    await frames(100)
    await shot("02-encounter")
    game.boss.action(game.ROAR,"review",[],1.0)
    game.audio.cue("boss_roar",game.boss.global_position)
    await frames(50)
    await shot("03-roar")
    game.player.action("ual2/Sword_Regular_A","review",[],0.2)
    await frames(55)
    await shot("04-player-sword")
    game.effects.blood(game.player.global_position+Vector3.UP*1.2,Vector3.FORWARD,45)
    await frames(16)
    await shot("05-blood")
    game.win()
    await frames(34)
    await frames(85)
    await shot("06-dissolve")
    await frames(110)
    await shot("07-victory-reward")
    print("PLAYABLE_V04_RENDER_COMPLETE")
    quit()
