extends SceneTree
var checks := 0
var failures: Array[String] = []
var measurements := {}
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
    checks+=1
    if not ok: failures.append(message)
func run():
    var game=load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    game.stage="review"
    game.effects.clear()
    game.skill_fx.set_process(false)
    for clip in ["Sprint_Loop","Jog_Fwd_Loop"]:
        var clearance := INF
        for i in 96:
            game.player.avatar.play_clip(clip,true,1,0)
            game.player.avatar.tick(float(game.player.avatar.manifest[clip].length)*i/96.0)
            game.player.weapon.tick(0)
            var blade: Transform3D=game.player.weapon.blade.global_transform
            var base: Vector3=blade*Vector3(0,0.43,0.12)
            var tip: Vector3=blade*Vector3(0,1.55,-0.22)
            var low: Vector3=game.player.avatar.bone_transform("hips").origin
            var high: Vector3=game.player.avatar.bone_transform("spine.003").origin
            var pair:=Geometry3D.get_closest_points_between_segments(base,tip,low,high)
            var distance:=pair[0].distance_to(pair[1])
            clearance=minf(clearance,distance)
            check(distance>0.20,"Sword clears torso "+clip+" phase "+str(i))
            var handle: Vector3=blade*Vector3(0.001,0.22,0.169)
            var palm: Transform3D=game.player.avatar.bone_transform("hand.R")*game.player.avatar.palm_socket
            check(handle.distance_to(palm.origin)<0.002,"Grip attached "+clip+" phase "+str(i))
        measurements[clip+"_minimum_torso_clearance_m"]=clearance
    game.reset()
    game.stage="review"
    game.player.position=game.world.ground(-80,40)
    game.boss.position=game.world.ground(30,-48)
    game.boss.face(game.boss.position+Vector3.BACK)
    var start: Vector3=game.boss.position
    var distance:=0.0
    var previous: Vector3=start
    var cycles:=0.0
    for i in 120:
        await physics_frame
        game.boss.motion(1.0/60,Vector3.BACK,true)
        var movement: Vector3=game.boss.position-previous
        distance+=Vector2(movement.x,movement.z).length()
        previous=game.boss.position
    cycles=game.boss.avatar.elapsed/float(game.boss.avatar.manifest[game.boss.clip].length)
    measurements.boss_distance_per_cycle_m=distance/cycles
    measurements.boss_distance_per_step_m=distance/cycles/2.0
    check(distance/cycles>10.0,"Boss advances substantially per animation cycle")
    check(game.skill_fx.groups.any(func(g):return g.kind=="foot"),"Boss footfall dust emitted")
    game.skill_fx.clear()
    game.player.position=game.world.ground(30,-40)
    game.player.idle()
    for i in 90:
        await physics_frame
        game.player.motion(1.0/60,Vector3.BACK,true)
    check(game.skill_fx.groups.any(func(g):return g.kind=="foot"),"Player footfall dust emitted")
    game.skill_fx.clear()
    game.skill_fx.impact(game.boss.position,Vector3.BACK,game.skills["combat-master-b05c145bc48d267a1ad9"])
    var parts: Array=game.skill_fx.groups[0].particles
    check(parts.any(func(p):return p.kind=="jet"),"Velocity-aligned sand jets exist")
    check(parts.any(func(p):return p.kind=="slab" and p.delay>0.2),"Progressively rising rocks exist")
    check(not game.skill_fx.groups[0].has("crack"),"No flat zigzag ground graphics")
    game.skill_fx._process(3.0)
    check(game.skill_fx.groups.is_empty(),"Impact instances released")
    for actor in [game.player,game.boss]:
        actor.weapon.visible=true
        actor.trail.set_process(false)
        var attack: String="ual2/Sword_Regular_A" if actor.role=="knight" else "combat-master-e04e545ae5e634c10286"
        actor.action(attack,"attack",[0.4])
        actor.avatar.play_clip(attack,false,1,0)
        var visible:=false
        for i in 60:
            var dt: float=actor.duration/100.0
            actor.time+=dt
            actor.avatar.tick(dt)
            actor.weapon.tick(dt)
            actor.trail._process(dt)
            if actor.trail.ribbon.get_surface_count()>0: visible=true
        check(visible,"Trail visible for "+actor.role)
        actor.hitstop_left=0.1
        var samples: Array=actor.trail.samples.duplicate(true)
        actor.trail._process(0.05)
        check(samples==actor.trail.samples,"Trail freezes with weapon "+actor.role)
        actor.hitstop_left=0
        actor.state="idle"
        actor.trail._process(0.5)
        check(actor.trail.samples.is_empty(),"Trail expires "+actor.role)
    FileAccess.open("res://qa/iteration-v08/regression.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"  "))
    print("V08_CHECKS ",checks," FAILURES ",failures," MEASUREMENTS ",measurements)
    for player in game.find_children("*","AudioStreamPlayer",true,false): player.stop()
    for player in game.find_children("*","AudioStreamPlayer3D",true,false): player.stop()
    await process_frame
    game.queue_free()
    await process_frame
    call_deferred("quit",0 if failures.is_empty() else 1)
