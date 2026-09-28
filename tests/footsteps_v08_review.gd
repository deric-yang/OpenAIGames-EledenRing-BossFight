extends SceneTree
var game: Node3D
func _initialize(): call_deferred("run")
func run():
    game=load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    game.effects.clear()
    game.hud.root.visible=false
    game.stage="review"
    game.skill_fx.set_process(false)
    game.camera_director.set_process(false)
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    for actor in [game.player,game.boss]:
        game.skill_fx.clear()
        if actor==game.boss: game.player.position=game.world.ground(80,50)
        actor.position=game.world.ground(-30,-35)
        actor.face(actor.position+Vector3.BACK)
        actor.idle()
        for i in 120:
            await physics_frame
            actor.motion(1.0/60,Vector3.BACK,true)
            game.skill_fx._process(1.0/60)
            var size:=1.0 if actor.role=="knight" else 3.5
            game.camera_director.position=actor.position+Vector3(3.0,1.8,3.6)*size
            game.camera_director.look_at(actor.position+Vector3.UP*1.0*size)
            if i%2==0:
                await process_frame
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v08/sequence/"+actor.role+"-run-"+str(i/2).pad_zeros(3)+".png"))
    quit()
