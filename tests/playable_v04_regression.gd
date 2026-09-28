extends SceneTree
var game: Node3D
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label); push_error(label)
func count(cue: String) -> int:
    return game.audio.cue_counts.get(cue,0)
func reset_pair(distance: float = 2.5) -> void:
    game.effects.clear()
    game.stage = "fight"
    game.boss_followup = ""
    game.player.reset_at(game.world.ground(0,0))
    game.boss.reset_at(game.world.ground(0,-distance))
    game.player.face(game.boss.global_position)
    game.boss.face(game.player.global_position)
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    for actor in [game.player,game.boss]:
        check(actor.avatar.baked,"Actor uses actual baked target skin")
        for clip in actor.avatar.manifest:
            actor.avatar.play_clip(clip,false,1,0)
            for fraction in [0.0,0.35,0.7,0.99]:
                actor.avatar.elapsed = actor.avatar.manifest[clip].length*fraction
                actor.avatar.tick(0.016)
                actor.weapon.tick(0.016)
                for bone in actor.avatar.rig.get_bone_count():
                    var pose: Transform3D = actor.avatar.rig.get_bone_global_pose(bone)
                    if not pose.is_finite() or pose.origin.length()>10:
                        failures.append("Invalid bone pose in "+clip)
            checks += 1
    reset_pair(20)
    var swings := count("player_swing_1")
    var blood := count("blood_hit")
    game.player_attack(0)
    game.contact(game.player,0)
    check(count("player_swing_1")==swings+1,"Swing always sounds on a miss")
    check(count("blood_hit")==blood and game.boss.hp==game.boss.max_hp,"Miss has no blood or damage")
    reset_pair()
    game.player_attack(0)
    game.contact(game.player,0)
    check(game.boss.hp==game.boss.max_hp-18,"Valid sword contact damages boss")
    check(count("blood_hit")==blood+1,"Valid contact emits blood sound")
    reset_pair()
    game.player.action("Roll","roll")
    game.boss.impact_damage = 31
    game.contact(game.boss,0)
    check(game.player.hp==100,"Roll invulnerability rejects contact")
    game.player.time = game.player.duration
    game.contact(game.boss,0)
    check(game.player.hp==69 and game.player.state=="launch","Heavy hit launches player outside invulnerability")
    game.action_finished(game.player)
    check(game.player.state=="down","Launch settles in recoverable down state")
    reset_pair()
    game.player_attack(0)
    for i in 7: game.contact(game.player,0)
    check(game.boss.stagger_left>0 and game.boss.state=="stagger","Seven hits open execution window")
    game.execute()
    check(game.stage=="execution" and game.player.clip==game.EXECUTION,"Selected player execution starts")
    game.player.time=game.player.duration*0.49
    var hp: float = game.boss.hp
    game._physics_process(0.016)
    check(game.boss.hp==hp-120 and count("execution")==1,"Execution layers sound and damages exactly once")
    game._physics_process(0.016)
    check(game.boss.hp==hp-120,"Execution impact does not repeat")
    reset_pair()
    game.player.hp=10
    game.boss.impact_damage=19
    game.contact(game.boss,0)
    check(game.stage=="defeat" and game.player.state=="dead","Lethal boss hit enters defeat")
    check(count("boss_victory")==1 and count("player_death")==1,"Defeat emits selected death and boss laugh")
    reset_pair()
    game.boss.hp=1
    game.player_attack(0)
    game.contact(game.player,0)
    check(game.stage=="victory","Lethal player hit enters victory")
    game._physics_process(0.6)
    check(not game.boss.weapon.visible and not game.boss.avatar.model.visible,"Victory removes weapon and dissolves actual boss")
    game.reset()
    check(game.stage=="intro" and game.player.hp==100 and game.boss.hp==680,"Restart restores encounter and resurrection")
    check(game.boss.avatar.model.visible,"Restart restores dissolved boss")
    check(game.audio.manifest.size()==18,"All 18 selected audio event groups are loaded")
    var report := {"checks":checks,"failures":failures,"boss_clips":game.boss.avatar.manifest.size(),"player_clips":game.player.avatar.manifest.size()}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/playable-v04"))
    FileAccess.open("res://qa/playable-v04/regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PLAYABLE_REGRESSION ",JSON.stringify(report))
    game.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
