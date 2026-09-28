extends SceneTree
var game: Node3D
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
    checks += 1
    if not value: failures.append(label); push_error(label)
func pair(distance: float = 2.6) -> void:
    game.reset()
    game.effects.clear()
    game.stage = "fight"
    game.ai_wait = 100
    game.player.reset_at(game.world.ground(8,-62))
    game.boss.reset_at(game.world.ground(8,-62-distance))
    game.player.face(game.boss.global_position)
    game.boss.face(game.player.global_position)
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await physics_frame
    await process_frame
    check(is_equal_approx(game.boss.avatar.scale.x,3.45946*1.25),"Boss enlarged exactly 1.25 times")
    check(not game.boss.avatar.manifest.has(game.REMOVED),"Removed agile combo absent from baked Boss")
    check(not game.attack_pool.has(game.REMOVED) and not game.attack_pool.has(game.HEAVY),"Removed and player-only moves excluded from AI")
    check(game.player.avatar.manifest.has(game.HEAVY),"Selected thrust retargeted to actual player")
    check(game.world.boss_position.y-game.world.respawn_position.y > 20,"Boss waits on elevated dune above player")
    var maximum_slope := 0.0
    for z in range(-35,10):
        maximum_slope = maxf(maximum_slope,absf(DuneHeightV04.sample(8,z+0.5)-DuneHeightV04.sample(8,z-0.5)))
    check(rad_to_deg(atan(maximum_slope))>26 and rad_to_deg(atan(maximum_slope))<38,"Ascent has a steep roughly thirty-degree slope")
    check(game.world.find_children("*","RespawnBonfire",true,false).is_empty(),"Old campfires removed")
    check(ResourceLoader.exists("res://assets/runtime/world/v05/column.glb") and ResourceLoader.exists("res://assets/runtime/world/v05/wall.glb"),"Both optimized Tripo ruins present")
    check(game.world.find_children("*","LuminousRelics",true,false).size()==1,"Golden rune weapons placed")
    game.stage = "approach"
    var origin: Vector3 = game.boss.position
    for i in 180: game._physics_process(1.0/60)
    check(game.stage=="approach" and Vector2(game.boss.position.x-origin.x,game.boss.position.z-origin.z).length()<0.01,"Boss does not chase during ascent")
    game.player.position = game.world.ground(8,-57)
    game._physics_process(0.016)
    check(game.stage=="fight" and game.boss.state=="intro","Combat activates only near the summit Boss")
    pair(20)
    game.player_heavy_attack()
    var stamina: float = game.player.stamina
    game.contact(game.player,0)
    check(game.player.clip==game.HEAVY and stamina==72,"Heavy attack uses selected thrust and stamina cost")
    check(game.player.hitstop_left==0 and not game.audio.cue_counts.has("blood_hit"),"Whiff has no hit-stop or blood")
    pair()
    game.player_heavy_attack()
    game.contact(game.player,0)
    check(game.boss.hp==game.boss.max_hp-34,"Heavy thrust applies damage")
    check(game.player.hitstop_left>=0.08 and game.boss.hitstop_left>=0.08,"Heavy impact pauses both actors")
    var elapsed: float = game.player.avatar.elapsed
    var clock: float = game.player.time
    var position: Vector3 = game.player.position
    game.player.motion(0.03,Vector3.FORWARD,false)
    check(game.player.time==clock and game.player.avatar.elapsed==elapsed and game.player.position==position,"Hit-stop freezes animation and displacement")
    game.player.motion(0.1,Vector3.ZERO,false)
    check(game.player.avatar.elapsed>elapsed and game.player.hitstop_left==0,"Animation resumes after finite hit-stop")
    pair()
    game.player_heavy_attack()
    for i in 30: game.player.motion(0.01,Vector3.ZERO,false)
    check(game.boss.hp==game.boss.max_hp,"Thrust windup does not damage before blade extension")
    for i in 80: game.player.motion(0.01,Vector3.ZERO,false)
    check(game.boss.hp==game.boss.max_hp-34 and game.audio.cue_counts.get("blood_hit")==1,"Timed thrust extension hits once across its active window")
    pair()
    game.player_attack(0)
    game.contact(game.player,0)
    check(game.player.hitstop_left>0.04 and game.player.hitstop_left<0.08,"Light combo has shorter hit-stop")
    pair()
    game.player_attack(0)
    for i in 7: game.contact(game.player,0)
    check(game.boss.clip=="Warden_Kneel_Enter","Stagger starts authored kneel transition")
    game.action_finished(game.boss)
    check(game.boss.state=="down" and game.boss.avatar.current=="Warden_Kneel_Hold" and game.boss.avatar.looping,"Execution window holds a kneeling pose")
    game.boss.avatar.blend_left=0
    game.boss.avatar.tick(0.01)
    var knee: Vector3 = game.boss.avatar.bone_transform("shin.R").origin
    check(absf(knee.y-game.boss.position.y)<0.15,"Rear knee rests at ground level")
    game.execute()
    check(game.stage=="execution" and game.camera_director.executing,"Execution enters arm-follow camera")
    game.player.time=game.player.duration*0.35
    game.player.avatar.elapsed=game.player.time
    game.player.avatar.blend_left=0
    game.player.avatar.tick(0.016)
    for i in 40: game.camera_director._process(1.0/60)
    check(game.camera_director.fov<58 and game.camera_director.execution_weight>0.9,"Execution camera eases closer")
    game.action_finished(game.player)
    check(not game.camera_director.executing and game.boss.clip=="Warden_Rise","Surviving Boss rises and camera returns")
    for i in 90: game.camera_director._process(1.0/60)
    check(is_equal_approx(game.camera_director.fov,62),"Normal camera restored")
    pair()
    game.boss.action("Warden_Kneel_Hold","down")
    game.boss.stagger_left=0
    game.boss_brain(0.016)
    check(game.boss.clip=="Warden_Rise","Expired execution window recovers")
    pair()
    game.player.hp=1
    game.contact(game.boss,0)
    for i in 8: game.contact(game.boss,0); game.audio.cue("player_death",game.player.position)
    check(game.audio.cue_counts.get("player_death")==1,"Death foley is emitted only once per life")
    check(game.player.state=="dead" and game.stage=="defeat","Dead player cannot restart an action")
    check(game.hud.death_panel.visible,"Red You Died panel appears")
    for voice in game.audio.voices:
        check(not voice.stream is AudioStreamWAV or voice.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"All one-shot streams explicitly disable embedded loops")
    game.audio.cue("boss_step",game.boss.position,-5)
    check(absf(game.audio.voices.back().volume_db-(-14-10.457575))<0.001,"Footstep amplitude reduced to thirty percent")
    game.audio.foot_scrape(game.player.position,true)
    check(absf(game.audio.scrape.volume_db-(-27-10.457575))<0.001,"Sand scrape loop also reduced to thirty percent")
    game.audio.start_ambient()
    game.audio.set_combat(true)
    check(game.audio.music.playing and game.audio.music.stream.loop,"Selected music loops during combat")
    game.audio.set_combat(false)
    game.audio._process(3)
    check(not game.audio.music.playing,"Music fades out outside combat")
    game.reset()
    check(not game.hud.death_panel.visible and game.audio.cue_counts.is_empty(),"Restart resets death UI and once-per-life sounds")
    check(game.hud.location_label.text=="古战场遗迹","Renamed battlefield shown")
    check(game.hud.boss_name.get_child(0).text=="王骸的守望者","Renamed Boss shown")
    check(game.boss.eyes.cores.size()==2,"Two head-attached red eyes")
    var eye_before: Vector3 = game.boss.eyes.cores[0].global_position
    game.boss.avatar.play_clip(game.ROAR,false,1,0)
    game.boss.avatar.elapsed=0.8
    game.boss.avatar.tick(0.016)
    game.boss.eyes.tick(0.016)
    check(game.boss.eyes.cores[0].global_position.distance_to(eye_before)>0.01,"Eyes follow animated head")
    game.player.action("ual2/Sword_Regular_A","attack",[0.4])
    game.player.time=game.player.duration*0.35
    game.player.weapon.visible=true
    game.player.trail.clear()
    game.player.trail._process(0.016)
    game.player.weapon.position.x+=0.2
    game.player.trail._process(0.016)
    check(game.player.trail.ribbon.get_surface_count()>0,"Weapon ribbon uses actual moving blade samples")
    game.player.idle()
    game.player.trail._process(0.2)
    check(game.player.trail.ribbon.get_surface_count()==0,"Weapon ribbon fades completely after attack")
    var report := {"checks":checks,"failures":failures,"maximum_ascent_degrees":rad_to_deg(atan(maximum_slope)),"boss_clips":game.boss.avatar.manifest.size()}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/polish-v05"))
    FileAccess.open("res://qa/polish-v05/regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("V05_POLISH_REGRESSION ",JSON.stringify(report))
    game.queue_free()
    await process_frame
    await create_timer(0.15).timeout
    quit(0 if failures.is_empty() else 1)
