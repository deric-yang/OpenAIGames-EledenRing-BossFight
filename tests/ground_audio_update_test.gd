extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok: failures.append(description); push_error(description)

func run() -> void:
    var game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.crown_intro.cancel_waiting()
    game.stage="fight"
    game.player.position=game.world.ground(50,-43)
    game.boss.position=game.world.ground(8,-53)
    game.boss.face(game.boss.position+Vector3.BACK)
    var fracture_skills := 0
    for id in game.attack_pool:
        var profile: Dictionary = game.skills[id]
        game.audio.reset_cues()
        game.hazards.clear()
        game.start_boss_attack(id)
        game.contact(game.boss,0)
        var delayed := float(profile.delay)>0
        var fracture: bool = profile.effect in ["eruption","fissure"]
        if fracture: fracture_skills+=1
        check(game.audio.cue_counts.get("ground_fracture",0)==(1 if fracture and not delayed else 0), "Sound matches visible first impact: "+id)
        if delayed:
            game.tick_hazards(float(profile.delay)-0.01)
            check(game.audio.cue_counts.get("ground_fracture",0)==0,"Thrust telegraph stays silent")
            game.tick_hazards(0.02)
            check(game.audio.cue_counts.get("ground_fracture",0)==1,"Delayed fracture starts sound once")
            for i in 30: game.tick_hazards(1.0/60)
            check(game.audio.cue_counts.get("ground_fracture",0)==1,"Travelling damage front never repeats the sound")
        elif fracture and profile.windows.size()>1:
            game.contact(game.boss,1)
            check(game.audio.cue_counts.get("ground_fracture",0)==2,"Each separate slam in a combo has its own impact")
    check(fracture_skills==4,"All four current rock-fracture skills are covered")
    game.audio.reset_cues()
    game.audio.fracture(Vector3.ZERO,{"effect":"push"})
    game.audio.fracture(Vector3.ZERO,{"effect":"sand"})
    check(game.audio.cue_counts.get("ground_fracture",0)==0,"Pushback and dust-only sweeps have no rock-drop sound")
    game.audio.rng.seed=928039
    var variants := {}
    for i in 16:
        game.audio.fracture(game.boss.position,{"effect":"eruption"})
        var stream: AudioStreamWAV = game.audio.voices.back().stream
        variants[snappedf(stream.get_length(),0.01)]=true
        check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and stream.get_length()<1.6,"First-wave sound is a short one-shot")
    check(variants.has(1.42) and variants.has(1.58),"Both reviewed source variants participate in random selection")
    game.audio.start_ambient()
    game.audio.set_combat(false,true)
    game.audio._process(2)
    check(game.audio.ambient.playing and game.audio.ambient.stream.loop,"Rumble loops before battle")
    check(game.audio.ambient.stream.get_length()>56 and game.audio.ambient.stream.get_length()<57,"Rumble contains the full body with the loop crossfade")
    check(is_zero_approx(game.audio.ambient.volume_db),"Prepared +30% rumble plays at unity gain")
    game.audio.set_combat(true,false)
    game.audio._process(2)
    check(not game.audio.ambient.playing and game.audio.music.playing,"Battle crossfades from rumble to Final Battle")
    game.audio.set_combat(false,false)
    game.audio._process(2)
    check(not game.audio.ambient.playing and not game.audio.music.playing,"Victory / death do not restart prebattle rumble")
    game.reset()
    game._physics_process(1.0/60)
    game.audio._process(2)
    check(game.audio.ambient.playing and not game.audio.music.playing,"Respawn restores the prebattle atmosphere")
    var report := {"checks":checks,"failures":failures,"fracture_skills":fracture_skills,"variant_durations":variants.keys()}
    FileAccess.open("res://qa/crown-continuity-20260928/audio-regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("GROUND_AUDIO_TEST ",JSON.stringify(report))
    # Flush the just-created respawn announcement before destroying the audio nodes.
    await create_timer(0.15).timeout
    game.audio.reset_cues()
    game.audio.set_combat(false,false)
    game.audio._process(2)
    game.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    quit(0 if failures.is_empty() else 1)
