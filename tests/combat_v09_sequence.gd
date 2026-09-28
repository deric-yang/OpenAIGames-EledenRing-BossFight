extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var game=load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    game.effects.clear()
    game.player.avatar.model.visible=true
    game.player.weapon.visible=true
    game.player.position=game.world.ground(8,-48)
    game.player.max_hp=10000
    game.player.hp=10000
    game.boss.position=game.world.ground(8,-53)
    game.boss.face(game.player.position)
    game.player.face(game.boss.position)
    game.stage="fight"
    game.ai_wait=0
    game.start_boss_attack(game.COUNTER)
    game.camera_director.set_process(false)
    game.camera_director.position=game.boss.position+Vector3(13,8,17)
    game.camera_director.look_at(game.boss.position+Vector3(0,3,2))
    game.hud.location_time=0
    var rows: Array=[]
    var previous := ""
    var out:="res://qa/iteration-v09/combat-sequence/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
    for i in 1800:
        await physics_frame
        if i==900:
            game.boss.action(game.ROAR,"roar",[0.38],0.85)
            game.director.cancel_sequence()
        game._physics_process(1.0/60)
        var current: String=game.boss.state+":"+game.boss.clip
        if previous!=current:
            rows.append({"time":i/60.0,"state":game.boss.state,"clip":game.boss.clip,"wait":game.ai_wait,"remaining":game.director.remaining})
            previous=current
        if i%3==0:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(out+"%04d.png"%(i/3))
    FileAccess.open("res://qa/iteration-v09/combat-timeline.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
    for audio in game.find_children("*","AudioStreamPlayer",true,false): audio.stop()
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false): audio.stop()
    game.queue_free()
    await process_frame
    quit()
