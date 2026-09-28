extends SceneTree
var game: Node3D
func _initialize(): call_deferred("run")
func shot(name: String):
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qa/iteration-v08/"+name+".png"))
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
    game.player.trail.set_process(false)
    game.boss.trail.set_process(false)
    game.player.position=game.world.ground(8,-44)
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    var report := {}
    for actor in [game.player,game.boss]:
        var clip := "Sprint_Loop" if actor.role=="knight" else "combat-master-577f7516d930b2ed0ead"
        var feet: Array = []
        for i in 32:
            actor.avatar.play_clip(clip,false,1,0)
            actor.avatar.tick(float(actor.avatar.manifest[clip].length)*i/32.0)
            feet.append({"phase":i/32.0,"left":actor.avatar.bone_transform("foot.L").origin.y-actor.position.y,
                "right":actor.avatar.bone_transform("foot.R").origin.y-actor.position.y,
                "left_z":(actor.global_transform.affine_inverse()*actor.avatar.bone_transform("foot.L").origin).z,
                "right_z":(actor.global_transform.affine_inverse()*actor.avatar.bone_transform("foot.R").origin).z})
        report[actor.role]=feet
        var attack := "ual2/Sword_Regular_A" if actor.role=="knight" else "combat-master-e04e545ae5e634c10286"
        actor.action(attack,"attack",[0.40])
        actor.avatar.play_clip(attack,false,1,0)
        actor.trail.clear()
        var origin: Vector3=actor.position
        var scale := 1.0 if actor.role=="knight" else 4.0
        game.camera_director.position=origin+Vector3(2.5,1.6,2.8)*scale
        game.camera_director.look_at(origin+Vector3.UP*1.0*scale)
        var duration: float=actor.avatar.manifest[attack].length
        for i in 48:
            var dt := duration/80.0
            actor.time+=dt
            actor.avatar.tick(dt)
            actor.weapon.tick(dt)
            actor.trail._process(dt)
            if i in [20,25,30,35,40]: await shot(actor.role+"-trail-"+str(i))
        actor.trail.clear()
    FileAccess.open("res://qa/iteration-v08/foot-phases.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    quit()
