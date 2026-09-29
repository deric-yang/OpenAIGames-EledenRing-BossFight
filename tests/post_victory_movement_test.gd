extends SceneTree
var game: Node3D
var checks := 0
var failures: Array[String] = []
const OUT := "res://qa/post-victory-v11-20260929/"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); push_error(label)

func step(frames: int) -> void:
    for i in frames:
        game._physics_process(1.0/60)
        await physics_frame

func restart_key() -> void:
    var key := InputEventKey.new()
    key.physical_keycode=KEY_R
    key.pressed=true
    game._unhandled_input(key)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    await physics_frame
    game.crown_intro.cancel_waiting()
    # Finish the real spawn reveal before this fixture jumps to the winning hit.
    game.effects._process(3.3)
    game.effects.clear()
    game.player.weapon.show()
    game.camera_director.intro=false
    game.stage="fight"
    game.commands.capture("attack")
    game.win()
    check(game.stage=="victory" and game.commands.buffer.pending.is_empty(),"Victory still clears pre-win input")
    check(game.commands.available(),"Fresh player commands are accepted after victory")
    check(not game.camera_director.locked_on,"Victory releases camera lock")
    var lock := InputEventAction.new()
    lock.action="lock_on"
    lock.pressed=true
    game.camera_director._unhandled_input(lock)
    check(not game.camera_director.locked_on,"Cannot relock a defeated invisible boss")
    check(not game.boss.get_collision_layer_value(2) and not game.boss.get_collision_mask_value(3),"Defeated boss no longer blocks the player")
    var start: Vector3=game.player.position
    Input.action_press("move_forward")
    await step(30)
    check(game.player.state=="move" and Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()>1,"WASD moves the actual player after victory")
    var stamina: float=game.player.stamina
    Input.action_press("sprint")
    await step(20)
    check(game.player.clip=="Sprint_Loop" and game.player.stamina<stamina,"Post-victory sprint retains normal stamina rules")
    Input.action_release("sprint")
    Input.action_release("move_forward")
    await step(1)
    var roll := InputEventAction.new()
    roll.action="roll"
    roll.pressed=true
    game.commands._input(roll)
    await step(1)
    check(game.player.state=="roll" and game.commands.buffer.pending.is_empty(),"Fresh roll uses V11 buffer and consumes once")
    var attack_id: int=game.player.attack_id
    await step(2)
    check(game.player.attack_id==attack_id,"Consumed victory roll is not replayed")
    check(game.stage=="victory" and game.boss.hp==0 and game.attack_count==0,"Free movement never resumes boss AI or combat")
    check(game.audio.cue_counts.get("announcement_victory",0)==1 and game.hud.victory_time>=0,"Victory announcement and reward sequence still run once")
    check(not game.boss.weapon.visible,"Boss dissolve hides its weapon on schedule")
    check("R restart" in game.status.text,"Victory explains how to restart")
    Input.action_press("move_forward")
    await step(60)
    Input.action_release("move_forward")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"victory-movement.png"))
    await step(30)
    restart_key()
    check(game.stage=="intro" and game.player.hp==200 and game.boss.hp==680,"R restores a full new encounter")
    check(game.player.position.is_equal_approx(game.world.respawn_position+Vector3.UP*0.05),"R returns player to the golden sigil")
    check(game.crown_intro.waiting and not game.crown_intro.played,"R rearms opening kneel and cinematic")
    check(game.camera_director.locked_on and game.boss.get_collision_layer_value(2) and game.boss.get_collision_mask_value(3),"R restores camera targeting and live boss collision")
    check(game.commands.buffer.pending.is_empty() and game.commands.combo_next==-1,"R retains V11 input and combo cleanup")
    check(game.hud.victory_time<0 and game.victory_wait<0,"R clears victory and reward timing")
    game.stage="defeat"
    game.player.hp=0
    game.player.state="dead"
    start=game.player.position
    Input.action_press("move_forward")
    await step(10)
    Input.action_release("move_forward")
    check(Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()<0.01,"Death remains dead until restart")
    restart_key()
    check(game.stage=="intro" and game.player.hp==200,"R still works after defeat")
    var report := {"checks":checks,"failures":failures}
    FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("POST_VICTORY ",JSON.stringify(report))
    game.audio.reset_cues()
    game.audio.set_combat(false,false)
    game.audio._process(2)
    game.queue_free()
    await process_frame
    await create_timer(0.3).timeout
    quit(0 if failures.is_empty() else 1)
