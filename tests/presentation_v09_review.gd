extends SceneTree
var game: Node3D
func _initialize(): call_deferred("run")
func shot(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://qa/iteration-v09/"+name+".png")
func run():
    game=load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    game.effects.clear()
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    game.hud.set_process(false)
    game.hud.location_time=0
    game.hud._process(0.01)
    var camera: Camera3D=game.camera_director
    camera.set_process(false)
    var spawn: Vector3=game.world.respawn_position
    game.player.avatar.tick(0.01)
    game.player.weapon.tick(0.01)
    camera.position=spawn+Vector3(5,7,6)
    camera.look_at(spawn)
    await shot("respawn-oblique")
    game.player.avatar.model.visible=false
    game.player.weapon.visible=false
    camera.position=spawn+Vector3(0,9,0.01)
    camera.look_at(spawn)
    await shot("respawn-top")
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    camera.position=spawn+Vector3(0,2.8,7)
    camera.look_at(game.boss.position+Vector3.UP*3)
    await shot("spawn-vista")
    game.hud.show_victory()
    game.hud._process(1.1)
    await shot("reward-and-victory")
    game.hud._process(2.3)
    await shot("reward-card")
    FileAccess.open("res://qa/iteration-v09/placements.json",FileAccess.WRITE).store_string(JSON.stringify(game.world.placements))
    FileAccess.open("res://qa/iteration-v09/fragments.json",FileAccess.WRITE).store_string(JSON.stringify(game.world.fragment_placements))
    game.queue_free()
    await process_frame
    quit()
