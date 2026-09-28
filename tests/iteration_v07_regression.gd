extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
    checks += 1
    if not value: failures.append(message); push_error(message)
func run():
    var game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    for id in [game.COUNTER,game.ROAR]:
        game.reset()
        game.stage="fight"
        game.player.position=game.world.ground(8,-50)
        game.boss.position=game.world.ground(8,-54)
        game.boss.face(game.player.position)
        if id==game.ROAR: game.boss.action(id,"roar",[0.38])
        else: game.start_boss_attack(id)
        game.contact(game.boss,0)
        check(game.player.hp==100,"Push/roar causes zero damage "+id)
        check(game.player.state=="pushback","Push/roar uses standing recoil "+id)
        check(game.player.velocity.y==0,"No launch velocity "+id)
        game.action_finished(game.player)
        check(game.player.state=="idle","Recoil recovers without down state "+id)
    for attack in 4:
        game.reset()
        game.effects.clear()
        game.stage="fight"
        game.player.position=game.world.ground(8,-51)
        game.boss.position=game.world.ground(8,-53)
        game.player.face(game.boss.position)
        game.boss.face(game.player.position)
        if attack==3: game.player_heavy_attack()
        else: game.player_attack(attack)
        game.player.avatar.tick(0.1)
        game.player.weapon.tick(0.1)
        game.contact(game.player,0)
        var frames := 10 if attack==3 else 8
        check(is_equal_approx(game.shared_hitstop,frames/60.0),"Requested hitstop frames "+str(attack))
        var player_time: float=game.player.avatar.elapsed
        var boss_time: float=game.boss.avatar.elapsed
        var weapon: Transform3D=game.player.weapon.global_transform
        var player_position: Vector3=game.player.global_position
        for frame in frames:
            game._physics_process(1.0/60)
            check(game.player.avatar.elapsed==player_time and game.boss.avatar.elapsed==boss_time,"Both skins frozen "+str(attack)+"/"+str(frame))
            check(game.player.weapon.global_transform.is_equal_approx(weapon),"Weapon frozen "+str(frame))
            check(game.player.global_position==player_position,"Displacement frozen "+str(frame))
        game._physics_process(1.0/60)
        game._physics_process(1.0/60)
        check(game.player.avatar.elapsed>player_time and game.boss.avatar.elapsed>boss_time,"Both resume together "+str(attack))
    game.reset()
    check(game.shared_hitstop==0,"Reset clears shared freeze")
    check(game.player.avatar.cape_bones.size()==12,"Complete cloak chains restored")
    check(game.player.avatar.model.find_children("Closed_Back_Armor","MeshInstance3D",true,false).is_empty(),"No patch armor")
    var triangles := 0
    for node in game.player.avatar.model.find_children("*","MeshInstance3D",true,false):
        for i in node.mesh.get_surface_count(): triangles += node.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
    check(triangles>=31000,"Complete authored mesh retained")
    for clip in ["Sword_Idle","ual2/Sword_Regular_A","ual2/Sword_Regular_B",game.HEAVY,"Sprint_Loop"]:
        game.player.avatar.play_clip(clip,false,1,0)
        game.player.avatar.tick(0.3)
        game.player.weapon.tick(0)
        var grip: Transform3D=game.player.avatar.bone_transform("hand.R")*game.player.avatar.palm_socket
        var actual_handle: Vector3=game.player.weapon.blade.global_transform*Vector3(0.001,0.22,0.169)
        check(actual_handle.distance_to(grip.origin)<0.002,"Physical handle is in palm "+clip)
    var voiced := 0
    for id in game.attack_pool:
        if game.skills[id].has("voice"): voiced+=1
    check(voiced>0 and voiced*2<=game.attack_pool.size(),"Less than half attacks voiced")
    for cue in ["boss_grunt_01","boss_grunt_03"]:
        game.audio.cue(cue,Vector3.ZERO)
        check(game.audio.cue_counts.get(cue,0)==1,"Exact grunt available "+cue)
    for cue in ["player_step","boss_step","boss_run"]:
        game.audio.cue(cue,Vector3.ZERO)
        check(not game.audio.cue_counts.has(cue),"Footsteps stay muted")
    game.audio.cue("player_death",Vector3.ZERO)
    game.audio.cue("player_death",Vector3.ZERO)
    check(game.audio.cue_counts.player_death==1,"Death drop still once")
    game.camera_director.impulse(0.1,0.15)
    for i in 11: game.camera_director._process(1.0/60)
    check(game.camera_director.shake_offset==Vector3.ZERO,"Shake returns to zero within 150ms")
    game.skill_fx.clear()
    game.skill_fx.impact(game.boss.position,game.boss.forward(),game.skills["combat-master-b05c145bc48d267a1ad9"])
    check(game.skill_fx.groups.size()==1,"One bounded instanced effect group")
    var particles: Array=game.skill_fx.groups[0].particles
    check(particles.any(func(p): return p.delay>0.2),"Fracture front propagates forwards")
    game.skill_fx._process(3)
    check(game.skill_fx.groups.is_empty(),"VFX releases its instances")
    game.reset()
    game.stage="fight"
    game.player.position=game.world.ground(8,-43)
    game.boss.position=game.world.ground(8,-53)
    game.boss.face(game.player.position)
    game.start_boss_attack("combat-master-b05c145bc48d267a1ad9")
    game.contact(game.boss,0)
    check(game.player.hp==100,"Fissure telegraph cannot damage")
    game.tick_hazards(0.86)
    check(game.player.hp==100,"Far target untouched when fracture starts")
    game.tick_hazards(0.1)
    check(game.player.hp==100,"Damage cannot outrun visible fracture")
    game.tick_hazards(0.2)
    check(game.player.hp==66,"Advancing front reaches target")
    game.tick_hazards(0.1)
    check(game.player.hp==66,"Wave hits each player once")
    game.shared_hitstop=0
    game.player.hitstop_left=0
    game.boss.hitstop_left=0
    game.player.idle()
    game.boss.idle()
    game.boss.position=game.world.ground(50,-45)
    game.boss.face(game.boss.position+Vector3.BACK)
    var start: Vector3=game.boss.position
    for i in 60: game.boss.motion(1.0/60,Vector3.BACK,true)
    check(Vector2(game.boss.position.x-start.x,game.boss.position.z-start.z).length()>7.5,"Boss sprint covers a full large stride")
    check(game.boss.avatar.speed>0.7 and game.boss.avatar.speed<0.9,"Boss cadence matches scaled stride")
    game.reset()
    game.stage="fight"
    game.player.position=game.world.ground(8,-51)
    game.boss.position=game.world.ground(8,-53)
    game.player.face(game.boss.position)
    game.boss.state="down"
    game.boss.stagger_left=100
    game.player_attack(0)
    var actual_contact := false
    for frame in 180:
        game._physics_process(1.0/60)
        if game.shared_hitstop>0:
            actual_contact=true
            break
    check(actual_contact and game.boss.hp<680,"Real attack window queues a damaging contact")
    var frozen_player: float=game.player.avatar.elapsed
    var frozen_boss: float=game.boss.avatar.elapsed
    for frame in 6:
        game._physics_process(1.0/60)
        check(game.player.avatar.elapsed==frozen_player and game.boss.avatar.elapsed==frozen_boss,"Deferred contact freezes both after the same tick")
    var file := FileAccess.open("res://qa/iteration-v07/regression.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
    print("V07_CHECKS ",checks," FAILURES ",failures)
    game.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
