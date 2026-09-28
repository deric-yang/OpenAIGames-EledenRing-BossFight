extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scenes/assembly_v04.tscn").instantiate()
    root.add_child(game)
    for i in 240: await physics_frame
    var passed: bool = game.preview_mode and game.stage=="explore" and game.player.hp==100 and game.boss.hp==680
    game.player.combo = 2
    game.reset()
    passed = passed and game.player.combo==0
    print("ASSEMBLY_V04_PREVIEW ",passed)
    quit(0 if passed else 1)
