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
    check(game.camera_director.current and game.boss.weapon.visible and game.player.avatar.model.visible,"Handoff restores actors, weapon and gameplay camera")
    intro.handoff()
    intro.advance(0.45)
    check(not intro.active and game.stage=="fight" and completions==1,"One natural completion after readable fade-in")
    check(game.player.position==start and game.player.hp==hp,"Handoff preserves approach position and HP")
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
    intro.start()
    check(not intro.active,"Motion review cannot trigger cinematic")
    var out := {"checks":checks,"failures":failures}
    FileAccess.open("res://qa/crown-intro-v01/regression.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
    print("CROWN_INTRO_TEST ",JSON.stringify(out))
    game.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
