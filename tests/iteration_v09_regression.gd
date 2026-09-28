extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func run():
    var game=load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await physics_frame
    await physics_frame
    for trigger in [game.COUNTER,game.ROAR]:
        for seed_value in 8:
            game.reset()
            game.stage="fight"
            game.rng.seed=seed_value+76
            game.player.position=game.world.ground(8,-48)
            game.boss.position=game.world.ground(8,-53)
            if trigger==game.ROAR: game.boss.action(trigger,"roar",[0.38])
            else: game.start_boss_attack(trigger)
            game.action_finished(game.boss)
            var budget: int=game.director.remaining
            check(budget in [1,2],"Bounded random follow-up budget")
            check(game.ai_wait<=0.30,"Immediate pressure after push/roar")
            check(not game.pending_roar,"Counter does not insert a second roar")
            game.boss_brain(0.31)
            check(game.boss.state=="attack" and game.boss.clip in game.attack_pool,"Push/roar follows into selected damaging attack")
            var first: String=game.boss.clip
            game.director.elapsed += game.boss.duration
            game.action_finished(game.boss)
            if budget==2:
                check(game.ai_wait<=0.32,"Short link interval")
                game.boss_brain(0.33)
                check(game.boss.state=="attack" and game.boss.clip!=first,"Followup variety, no immediate repeat")
                game.action_finished(game.boss)
            check(game.director.remaining==0 and game.ai_wait>=0.65,"Finite combo leaves punish window")
    game.reset()
    game.stage="fight"
    game.player.position=game.world.ground(8,-41.5)
    game.boss.position=game.world.ground(8,-53)
    game.ai_wait=0
    game.boss_brain(0.01)
    check(game.skills[game.boss.clip].shape=="lane","Long range chooses reachable thrust")
    game.director.remaining=2
    game.win()
    check(game.director.remaining==0,"Victory cancels queued pressure")
    game.reset()
    check(game.director.recent.is_empty() and game.director.cooldowns.is_empty(),"Reset clears AI history and cooldowns")
    # Verify the full circular rune against the actual physics surface, not only height math.
    var center: Vector3=game.world.respawn_position
    var state: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
    for ring in [0.0,0.8,1.72,2.3]:
        for i in 24:
            var position:=center+Vector3(cos(i*TAU/24)*ring,0,sin(i*TAU/24)*ring)
            var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*4,position-Vector3.UP*4,1)
            var hit:=state.intersect_ray(query)
            check(not hit.is_empty() and absf(hit.position.y-(center.y-0.05))<0.012,"Flat render/collision under entire rune")
    for id in game.boss.avatar.manifest:
        game.boss.avatar.play_clip("Sword_Idle",true,1,0)
        game.boss.avatar.tick(0.2)
        game.boss.avatar.play_clip(id,false)
        for i in 12:
            game.boss.avatar.tick(1.0/60)
            var grip: Transform3D=game.boss.avatar.weapon_transform()
            check(grip.origin.distance_to(game.boss.avatar.bone_transform("hand.R").origin)<0.25,"Boss weapon stays in palm during blend: "+id)
    var font:=load("res://assets/runtime/fonts/WeepingDunesSerifSC.ttf") as FontFile
    for c in "霸王之枪": check(font.has_char(c.unicode_at(0)),"Reward glyph "+c)
    var icon_image:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/runtime/ui/v09/overlords-spear.png"))
    check(icon_image.detect_alpha()!=Image.ALPHA_NONE,"Item icon preserves transparency")
    var report:={"checks":checks,"failures":failures}
    FileAccess.open("res://qa/iteration-v09/regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("V09_CHECKS ",JSON.stringify(report))
    for audio in game.find_children("*","AudioStreamPlayer",true,false): audio.stop()
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false): audio.stop()
    game.queue_free()
    await process_frame
    call_deferred("quit",0 if failures.is_empty() else 1)
