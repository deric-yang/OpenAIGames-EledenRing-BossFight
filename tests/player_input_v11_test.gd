extends SceneTree
var checks := 0
var failures: Array[String] = []
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); push_error(label)
func begin() -> void:
    game.reset()
    game.crown_intro.cancel_waiting()
    game.stage = "explore"
    game.player.idle()
func run() -> void:
    game = load("res://scenes/playable_v04.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    var c: PlayerCommands = game.commands
    check(is_equal_approx(c.buffer.ttl, 0.2) and c.buffer.policy == "protect_dodge", "Approved D defaults")
    check(game.crown_intro.waiting and game.player.hp == 200, "Opening kneel and 200 HP preserved")
    begin()
    c.capture("attack"); c.tick(0)
    check(game.player.combo == 0 and game.player.stamina == 84, "First light consumes one input")
    game.player.time = 0.27
    c.capture("attack"); c.tick(0)
    check(game.player.combo == 1, "First chains to second")
    game.player.time = game.player.duration
    game.action_finished(game.player)
    check(c.combo_next == 2 and game.player.state == "idle", "Natural second recovery remembers third")
    c.tick(0.12); c.capture("attack"); c.tick(0)
    check(game.player.combo == 2, "Late third input continues instead of restarting first")
    check(game.player.impacts.size() == 3, "Third retains all three hit marks")
    game.player.time = game.player.duration
    game.action_finished(game.player)
    c.capture("attack"); c.tick(0)
    check(game.player.combo == 0, "Completed third starts a new combo")
    begin(); game.player_attack(1)
    Input.action_press("move_forward")
    game.player.time = 0.50; c.tick(0)
    Input.action_release("move_forward")
    check(game.player.state == "idle" and c.combo_next == 2, "Movement recovery keeps short third-link grace")
    c.tick(0.201); c.capture("attack"); c.tick(0)
    check(game.player.combo == 0, "Expired continuation returns to first")
    begin(); game.player_attack(1)
    game.player.time = 0.10; c.capture("roll"); c.capture("attack")
    check(c.buffer.pending.action == "roll", "Roll intent protected from attack mash")
    c.tick(0.201)
    check(c.buffer.pending.is_empty(), "Input expires at 200ms")
    game.freeze_combat(8); c.capture("heavy_attack")
    var stamp := c.buffer.clock
    var actor_time: float = game.player.time
    game._physics_process(1.0 / 60)
    check(c.buffer.clock == stamp and game.player.time == actor_time, "Hitstop preserves both clock and actor")
    check(c.buffer.pending.action == "heavy_attack", "Input received during hitstop")
    begin(); game.player.state = "down"
    c.capture("roll"); c.tick(0)
    check(game.player.state == "roll", "Knockdown retains fresh-roll recovery")
    var attack_id: int = game.player.attack_id
    c.capture("roll"); c.tick(0.05)
    check(game.player.attack_id == attack_id, "Roll cannot restart its invulnerability")
    c.clear("forced_hit")
    check(c.buffer.pending.is_empty() and c.combo_next == -1, "Interrupt clears input and combo memory")
    begin(); game.player.stamina = 15
    c.capture("attack"); c.tick(0)
    check(game.player.state == "idle", "Insufficient stamina does not start attack")
    game.player.stamina = 16; c.tick(0.01)
    check(game.player.state == "attack" and game.player.stamina == 0, "Resources checked again at execution")
    var result := {"checks": checks, "failures": failures}
    FileAccess.open("res://qa/input-v11-20260929/results.json", FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("INPUT_V11 ", JSON.stringify(result))
    game.audio.reset_cues(); game.queue_free()
    await process_frame
    await create_timer(0.3).timeout
    quit(0 if failures.is_empty() else 1)
