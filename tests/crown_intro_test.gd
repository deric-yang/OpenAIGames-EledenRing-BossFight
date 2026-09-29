extends SceneTree
var game: Node3D
var checks := 0
var failures: Array[String] = []
var completions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok: failures.append(description); push_error(description)
func begin() -> void:
    game.reset()
    game.effects.clear()
    game.player.position = game.world.ground(8,-41)
    game.player.face(game.boss.position)
    game.boss.face(game.player.position)
    game.crown_intro.start()
    game.crown_intro.set_process(false)
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    var intro = game.crown_intro
    intro.completed.connect(func(_skipped): completions += 1)
    check(intro.waiting and game.boss.state=="ceremony", "Boss starts in the crown-holding kneel")
    var waiting_head: Vector3 = game.boss.avatar.bone_transform("head").origin
    var waiting_prop = intro.prop
    for i in 240: game._physics_process(1.0/60)
    check(intro.waiting and game.boss.avatar.bone_transform("head").origin.is_equal_approx(waiting_head), "Spawn and idle keep the kneeling pose without starting combat")
    check(intro.prop==waiting_prop and not intro.active and intro.elapsed==0, "Crown waits intact on the same ceremonial set")
    check(game.player.hp==200 and game.player.max_hp==200 and game.boss.max_hp==680, "Player health doubles; boss health stays unchanged")
    game.player.hp=34
    game.reset()
    check(game.player.hp==200 and intro.waiting, "Respawn restores 200 HP and the opening kneel")
    begin()
    var start: Vector3 = game.player.position
    var hp: float = game.player.hp
    var stamina: float = game.player.stamina
    var clock: float = game.clock
    Input.action_press("attack")
    Input.action_press("move_forward")
    game._physics_process(1.0)
    Input.action_release("attack")
    Input.action_release("move_forward")
    check(game.player.position==start and game.player.hp==hp and game.player.stamina==stamina and game.clock==clock,"Cinematic freezes movement, damage, stamina and gameplay clock")
    check(not game.hud.root.visible and not game.boss.weapon.visible,"Battle HUD and held polearm hidden")
    for entry in [[1.0,0],[3.0,1],[6.0,2],[8.6,3]]:
        intro.sample(entry[0])
        check(intro.shot_index==entry[1],"Shot boundary "+str(entry))
        check(intro.hand_errors.x<0.015 and intro.hand_errors.y<0.015,"Both wrists reach crown grips "+str(entry))
    intro.sample(9.4)
    check(is_equal_approx(intro.overlay.color.a,0.5),"Natural fade reaches half opacity at 9.4 seconds")
    intro.sample(9.99)
    intro.advance(0.02)
    check(intro.returning and intro.active and intro.overlay.color.a==1.0,"Natural ending switches camera under full black")
    check(game.camera_director.current and not game.boss.weapon.visible and game.player.avatar.model.visible,"Handoff restores player and camera but keeps the boss kneeling")
    intro.handoff()
    intro.advance(0.45)
    check(not intro.active and game.stage=="fight" and completions==1,"One natural completion after readable fade-in")
    check(game.player.position==start and game.player.hp==hp,"Handoff preserves approach position and HP")
    check(game.boss.state=="getup" and game.boss.clip==game.STANDUP and game.boss.weapon.visible, "Only completed cinematic starts the armed rise into combat")
    var rise_duration: float = game.boss.duration
    for i in ceili(rise_duration*60)+2: game._physics_process(1.0/60)
    check(game.boss.state in ["idle","move"] and game.attack_count==0, "Boss completes the rise before attacking")
    check(game.boss.avatar.bone_transform("head").origin.y > waiting_head.y+1, "Rise visibly brings the boss to standing height")
    begin()
    var key := InputEventKey.new()
    key.physical_keycode=KEY_ESCAPE
    key.pressed=true
    intro._input(key)
    intro.advance(0.6)
    key.pressed=false
    intro._input(key)
    intro.advance(0.3)
    check(intro.skip_time<0 and intro.hold_time==0,"Short ESC and release do not skip")
    key.pressed=true
    intro._input(key)
    intro.advance(0.81)
    intro.advance(0.31)
    check(intro.was_skipped and intro.returning and intro.overlay.color.a==1.0,"Held ESC uses the shared black handoff")
    intro.advance(0.46)
    check(not intro.active and completions==2 and game.stage=="fight","Skip restores battle once")
    check(game.boss.state=="getup", "Skip uses the same kneel-to-rise combat transition")
    begin()
    intro._input(key)
    intro.advance(0.5)
    intro._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(not intro.escape_down and intro.hold_time==0,"Focus loss clears held escape")
    intro._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    game.reset()
    check(not intro.active and not intro.played and not intro.canvas.visible,"Reset aborts the sequence and rearms it")
    check(game.camera_director.is_processing() and game.camera_director.is_processing_unhandled_input(),"Reset restores camera update and input")
    game.stage="approach"
    game.player.position=game.world.ground(game.boss.position.x,game.boss.position.z+12)
    game._physics_process(1.0/60)
    intro.set_process(false)
    check(intro.active and game.stage=="cinematic","Real approach threshold starts the intro before any attack")
    intro.sample(10.0)
    intro.advance(0.01)
    intro.advance(0.46)
    check(intro.played and game.stage=="fight","Approach intro unlocks fighting")
    var before := game.boss.avatar.elapsed as float
    game._physics_process(1.0/60)
    check(game.boss.avatar.elapsed>before,"Normal actor ticking resumes after the handoff")
    game.reset()
    game.review_dashboard=true
    intro.cancel_waiting()
    intro.start()
    check(not intro.active,"Motion review cannot trigger cinematic")
    check(not intro.waiting and intro.stage_root==null and game.boss.weapon.visible, "Motion review removes ceremonial props and restores the held weapon")
    game.audio.start_ambient()
    game.audio.set_combat(false)
    check(game.audio.music_target==-60, "Exploration and ceremony do not start combat music")
    game.audio.set_combat(true)
    var music: AudioStreamPlayer = game.audio.music
    check(music.stream.resource_path==BattleAudio.BATTLE_MUSIC and music.stream.loop, "Combat uses the new looping Final Battle recording")
    check(music.stream.get_length()>298 and music.stream.get_length()<299, "Complete 4:58 recording is imported, without truncation")
    check(music.playing and game.audio.music_target==BattleAudio.MUSIC_GAIN, "Battle music starts at the established mix gain")
    music.seek(music.stream.get_length()-0.08)
    await create_timer(0.3).timeout
    check(music.playing and music.get_playback_position()<1, "End of recording wraps into its next loop")
    game.audio.set_combat(false)
    game.audio._process(3)
    check(not music.playing, "Leaving combat fades music out and stops it")
    game.audio.set_combat(true)
    game.audio.reset_cues()
    check(not music.playing and game.audio.music_target==-60, "Respawn clears the old combat soundtrack")
    var bar_size: Vector2 = game.hud.player_track.size
    game.player.hp=100
    game.hud._process(0)
    check(is_equal_approx(game.hud.player_track.value,0.5), "100 health is now half of the same player bar")
    check(game.hud.player_track.size==bar_size, "Changing health never resizes the HUD")
    var out := {"checks":checks,"failures":failures}
    FileAccess.open("res://qa/crown-intro-v01/regression.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
    print("CROWN_INTRO_TEST ",JSON.stringify(out))
    game.queue_free()
    await process_frame
    # Let the audio mixer release active stream playbacks before the headless exit.
    await create_timer(0.15).timeout
    quit(0 if failures.is_empty() else 1)
