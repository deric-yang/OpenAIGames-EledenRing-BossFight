extends SceneTree
var game: Node3D
var steps := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.player.reset_at(game.world.ground(8,20)+Vector3.UP*0.05)
    game.player.avatar.playing=false
    game.player.weapon.visible=false
    game.player.trail.set_process(false)
    game.boss.trail.set_process(false)
    game.camera_director.set_process(false)
    game.audio.set_process(false)
    for i in 1450:
        game.player.motion(1.0/60,Vector3(0,0,-1),false)
        steps=i
        if game.player.position.z < -52: break
        if i%120==0: await physics_frame
    var ok: bool = game.player.position.z < -52 and game.player.position.y>23
    var report := {"passed":ok,"steps":steps,"position":str(game.player.position),"on_floor":game.player.is_on_floor()}
    FileAccess.open("res://qa/polish-v05/ascent-walk.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("V05_ASCENT_WALK ",JSON.stringify(report))
    game.queue_free()
    await process_frame
    quit(0 if ok else 1)
