extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String) -> void:
    checks += 1
    if not value: failures.append(message); push_error(message)
func run() -> void:
    var game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/iteration-v06/user-motion-review.json"))
    for row in review.motions:
        if row.status == "remove":
            check(not game.attack_pool.has(row.id),"Removed move absent from AI "+row.id)
            check(not game.boss.avatar.manifest.has(row.id),"Removed move absent from review "+row.id)
    check(game.world.respawn_position.distance_to(game.world.boss_position)<40,"Short approach")
    check(game.world.respawn_position.distance_to(game.world.boss_position)>14,"No spawn aggro")
    for cue in ["player_step","boss_step","boss_run","player_steps_loop"]:
        game.audio.cue(cue,Vector3.ZERO)
        check(not game.audio.cue_counts.has(cue),"Muted footsteps "+cue)
    game.audio.cue("player_death",Vector3.ZERO)
    game.audio.cue("player_death",Vector3.ZERO)
    check(game.audio.cue_counts.player_death==1,"Death event exactly once")
    var sound: AudioStreamWAV = load("res://assets/runtime/audio/v06/sword_drop_single.wav")
    check(sound.get_length()<2.21,"Death sample contains only first drop")
    game.audio.announce("death")
    game.audio.announce("death")
    check(game.audio.cue_counts.announcement_death==1,"Announcement exactly once")
    var profile: Dictionary = game.skills["combat-master-b05c145bc48d267a1ad9"]
    check(WardenHitGeometry.contains(profile,Vector3.ZERO,Vector3.FORWARD,Vector3(0,0,-10)),"Fissure forward reach")
    check(not WardenHitGeometry.contains(profile,Vector3.ZERO,Vector3.FORWARD,Vector3(3,0,-10)),"Fissure lateral escape")
    check(not WardenHitGeometry.contains(profile,Vector3.ZERO,Vector3.FORWARD,Vector3(0,0,3)),"Fissure excludes rear")
    game.stage = "fight"
    game.player.global_position = game.boss.global_position+game.boss.forward()*8
    game.player.hp = 100
    game.start_boss_attack("combat-master-b05c145bc48d267a1ad9")
    game.contact(game.boss,0)
    check(game.player.hp==100 and game.hazards.size()==1,"Telegraph before damage")
    game.tick_hazards(0.4)
    check(game.player.hp==100,"Fissure warning delay")
    game.tick_hazards(0.5)
    check(game.player.hp==66 and game.player.state=="launch","Delayed fissure launches")
    game.tick_hazards(1)
    check(game.player.hp==66,"Fissure damages only once")
    game.player.avatar.play_clip(game.HEAVY,false,1,0)
    game.player.avatar.tick(0.35)
    check(game.player.avatar.uses_corrected_grip,"Heavy animation mirrored with right-hand grip")
    check(game.player.avatar.weapon_transform().origin.distance_to(game.player.avatar.bone_transform("hand.R").origin)<0.25,"Weapon remains attached to right hand")
    check(game.player.avatar.cape_bones.is_empty(),"Player cape physics disabled after geometry removal")
    var triangles := 0
    for node in game.player.avatar.model.find_children("*","MeshInstance3D",true,false):
        for i in node.mesh.get_surface_count(): triangles += node.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
    check(triangles<26000 and triangles>18000,"Long cape removed, armor geometry retained")
    game.player.avatar.elapsed = float(game.player.avatar.manifest[game.HEAVY].length)*0.4
    game.player.avatar.tick(0)
    var local_tip: Vector3 = game.player.avatar.global_transform.affine_inverse()*(game.player.avatar.weapon_transform()*Vector3(0,1.2,0))
    check(local_tip.z>2.1 and absf(local_tip.x)<0.4,"Mirrored thrust sword points forward at impact")
    for index in 4:
        game.reset()
        game.effects.clear()
        game.stage = "fight"
        game.player.global_position = game.world.ground(8,-48)
        game.boss.global_position = game.world.ground(8,-50.5)
        game.player.face(game.boss.global_position)
        game.boss.face(game.player.global_position)
        if index==3: game.player_heavy_attack()
        else: game.player_attack(index)
        game.contact(game.player,0)
        var freeze: float = 0.22 if index==3 else 0.13
        check(is_equal_approx(game.player.hitstop_left,freeze),"Stronger hit-stop attack "+str(index))
        var elapsed: float = game.player.avatar.elapsed
        game.player.motion(0.08,Vector3.ZERO,false)
        check(is_equal_approx(game.player.avatar.elapsed,elapsed),"Skin actually frozen attack "+str(index))
        game.player.hitstop_left=0
        game.boss.global_position += Vector3(30,0,0)
        game.contact(game.player,0)
        check(game.player.hitstop_left==0,"Miss has no hit-stop "+str(index))
    for id in game.skills:
        game.stage="fight"
        game.boss.hp=game.boss.max_hp
        game.player.hp=100
        game.player.global_position=game.boss.global_position+Vector3(40,0,0)
        game.start_boss_attack(id)
        game.boss.avatar.blend_left=0
        game.boss.avatar.tick(float(game.boss.avatar.manifest[id].length)*0.45)
        game.boss.weapon.tick(0.016)
        game.contact(game.boss,0)
        game.skill_fx._process(0.1)
        check(game.boss.avatar.weapon_transform().origin.is_finite(),"Valid armed pose and effect "+str(id))
        game.skill_fx.clear()
        game.hazards.clear()
    game.boss.action(game.ROAR,"roar",[0.38])
    game.contact(game.boss,0)
    check(game.skill_fx.groups.size()==1 and game.skill_fx.groups[0].kind=="roar","Roar creates red glow without debris")
    print("V06_REGRESSION ",JSON.stringify({"checks":checks,"failures":failures}))
    sound = null
    game.queue_free()
    await process_frame
    await create_timer(0.2).timeout
    quit(0 if failures.is_empty() else 1)
