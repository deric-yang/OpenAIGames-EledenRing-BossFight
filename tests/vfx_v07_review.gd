extends SceneTree
var game: Node3D
func _initialize(): call_deferred("run")
func shot(name: String):
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v07/"+name+".png"))
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
    game.player.position=game.world.ground(8,-49)
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    game.boss.face(game.player.position)
    game.player.face(game.boss.position)
    game.boss.avatar.tick(0.1)
    game.boss.weapon.tick(0.1)
    game.player.avatar.tick(0.1)
    game.player.weapon.tick(0.1)
    var base: Vector3=game.boss.position
    game.camera_director.position=base+Vector3(11,7,13)
    game.camera_director.look_at(base+Vector3(0,1.5,4))
    for id in ["combat-master-b05c145bc48d267a1ad9","combat-master-b786d0b86e8a5ac01cec","combat-master-e04e545ae5e634c10286"]:
        game.skill_fx.clear()
        game.skill_fx.impact(base,Vector3.BACK,game.skills[id])
        for i in 3:
            game.skill_fx._process(0.16)
            await shot(id+"-"+str(i))
    game.skill_fx.clear()
    game.skill_fx.roar(base)
    game.skill_fx._process(0.15)
    await shot("roar")
    game.print_metrics()
    quit()
