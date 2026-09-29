class_name PlayerCommands
extends Node
## Approved 200ms single-intent buffer and authored action cancellation windows.
var game: Node3D
var buffer := preload("res://scripts/combat/command_buffer.gd").new()
var settings: Dictionary
var combo_next := -1
var combo_left := 0.0

func setup(encounter: Node3D) -> void:
    game = encounter
    settings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/combat/player-input-v11.json"))
    buffer.ttl = float(settings.buffer_seconds)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.__combatBlur=false;window.addEventListener('blur',()=>window.__combatBlur=true);document.addEventListener('visibilitychange',()=>{if(document.hidden)window.__combatBlur=true;});")

func clear(reason: String) -> void:
    buffer.clear(reason)
    combo_next = -1
    combo_left = 0
    if game and game.player: game.player.queued = false

func poll_focus() -> void:
    if OS.has_feature("web") and JavaScriptBridge.eval("Boolean(window.__combatBlur)"):
        JavaScriptBridge.eval("window.__combatBlur=false")
        clear("focus_lost")
        for key in ["attack", "heavy_attack", "roll", "move_left", "move_right", "move_forward", "move_back", "sprint"]:
            Input.action_release(key)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear("focus_lost")

func _input(event: InputEvent) -> void:
    if not game or (event is InputEventKey and event.echo): return
    for action in ["roll", "heavy_attack", "attack"]:
        if event.is_action_pressed(action):
            capture(action)
            return

func available() -> bool:
    return not game.review_dashboard and not game.crown_intro.active and game.stage in ["ready", "fight", "approach", "explore", "review", "victory"]

func direction() -> Vector3:
    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var vector: Vector3 = game.camera_director.global_basis.x * axis.x + game.camera_director.global_basis.z * axis.y
    vector.y = 0
    return vector.normalized()

func capture(action: String) -> void:
    if not available() or game.player.state in ["dead", "execution", "launch"]: return
    if game.player.state == "down" and action != "roll": return
    buffer.offer(action, direction())

func window(action: String) -> float:
    var p: BattleActor = game.player
    var move: Dictionary = settings.moves.get(p.clip, {})
    if move.is_empty(): return p.duration
    var last := 0.0
    for hit in p.impacts: last = maxf(last, float(hit) * p.duration)
    return minf(p.duration, maxf(float(move.roll if action == "roll" else move.chain), last + 1.0 / 60.0))

func permitted(action: String) -> bool:
    if not available() or game.shared_hitstop > 0: return false
    var p: BattleActor = game.player
    if p.state in ["idle", "move"]: return true
    if p.state == "down": return action == "roll"
    return p.state == "attack" and p.time + 0.00001 >= window(action)

func remember_chain() -> void:
    var p: BattleActor = game.player
    if p.state == "attack" and not p.heavy_attack and p.combo < 2:
        combo_next = p.combo + 1
        combo_left = float(settings.combo_grace_seconds)

func tick(delta: float) -> void:
    if not available():
        clear("state_locked")
        return
    buffer.advance(delta)
    combo_left = maxf(0.0, combo_left - delta)
    if combo_left <= 0: combo_next = -1
    var p: BattleActor = game.player
    if not buffer.pending.is_empty():
        var action: String = buffer.pending.action
        var cost := 25.0 if action == "roll" else (28.0 if action == "heavy_attack" else 16.0)
        if permitted(action) and p.stamina >= cost:
            var request := buffer.consume()
            var next := combo_next if combo_left > 0 else 0
            if p.state == "attack" and not p.heavy_attack: next = (p.combo + 1) % 3
            clear("consumed")
            if action == "roll":
                p.stamina -= cost
                p.move_direction = request.direction if request.direction.length_squared() > 0.01 else p.forward()
                p.face(p.global_position + p.move_direction)
                p.action("Roll", "roll", [], 1.33333)
            elif action == "heavy_attack": game.player_heavy_attack()
            else: game.player_attack(maxi(0, next))
            return
    if p.state == "attack" and buffer.pending.is_empty() and direction().length_squared() > 0.01:
        var move: Dictionary = settings.moves.get(p.clip, {})
        if not move.is_empty() and p.time >= float(move.move):
            remember_chain()
            p.idle()
