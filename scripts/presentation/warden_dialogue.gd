class_name WardenDialogue
extends Node
## Offline Victor recordings. This component never contacts an API at runtime.
const CATALOG := "res://assets/runtime/dialogue/warden-victor.json"
const FONT := "res://assets/runtime/fonts/WardenDialogueSerifSC.ttf"
var game: Node
var lines: Dictionary = {}
var streams: Dictionary = {}
var voice: AudioStreamPlayer
var canvas: CanvasLayer
var subtitle_root: Control
var subtitle: Label
var current_id := ""
var pending_id := ""
var pending_delay := 0.0
var terminal_id := ""
var seen := {}
var play_counts := {}
var age := 0.0
var tail_left := -1.0
var cooldown := 0.0
var focused := true
var heavy_count := 0
var heavy_choice := 1
var rng := RandomNumberGenerator.new()

func setup(owner_game: Node) -> void:
    game = owner_game
    lines = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)).lines
    for id in lines:
        if ResourceLoader.exists(lines[id].file):
            var stream: AudioStreamMP3 = load(lines[id].file).duplicate()
            stream.loop = false
            streams[id] = stream
    voice = AudioStreamPlayer.new()
    voice.name = "VictorVoice"
    voice.volume_db = -2.0
    add_child(voice)
    voice.finished.connect(_voice_finished)
    # Separate from HUDRoot, which the crown sequence hides. Above cinematic bars.
    canvas = CanvasLayer.new()
    canvas.layer = 95
    add_child(canvas)
    subtitle_root = Control.new()
    subtitle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(subtitle_root)
    subtitle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    subtitle = Label.new()
    subtitle.name = "WardenSubtitle"
    subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    subtitle_root.add_child(subtitle)
    subtitle.anchor_left = 0.12
    subtitle.anchor_right = 0.88
    subtitle.anchor_top = 0.923
    subtitle.anchor_bottom = 0.968
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_override("font", load(FONT))
    subtitle.add_theme_color_override("font_color", Color("d7d4ca"))
    subtitle.add_theme_color_override("font_shadow_color", Color(0.015, 0.012, 0.009, 0.95))
    subtitle.add_theme_constant_override("shadow_offset_x", 1)
    subtitle.add_theme_constant_override("shadow_offset_y", 2)
    subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.017, 0.01, 0.65))
    subtitle.add_theme_constant_override("outline_size", 2)
    subtitle.hide()
    subtitle_root.resized.connect(_fit_text)
    _fit_text()
    rng.randomize()
    reset_encounter()

func _fit_text() -> void:
    var factor := clampf(minf(subtitle_root.size.x / 1280.0, subtitle_root.size.y / 720.0), 0.55, 1.6)
    subtitle.add_theme_font_size_override("font_size", roundi(24 * factor))

func reset_encounter() -> void:
    stop()
    seen.clear()
    play_counts.clear()
    terminal_id = ""
    cooldown = 0.0
    heavy_count = 0
    # A separate RNG must not change the established combat AI sequence.
    heavy_choice = rng.randi_range(1, 3)

func stop() -> void:
    if voice: voice.stop()
    current_id = ""
    pending_id = ""
    pending_delay = 0.0
    tail_left = -1.0
    age = 0.0
    if subtitle:
        subtitle.text = ""
        subtitle.hide()
    if game and game.audio: game.audio.dialogue_active = false

func say(id: String, interrupt := false, delay := 0.0) -> bool:
    if not lines.has(id) or not streams.has(id) or seen.has(id): return false
    if terminal_id != "" and id != terminal_id: return false
    if not interrupt and (current_id != "" or pending_id != "" or cooldown > 0): return false
    stop()
    pending_id = id
    pending_delay = delay
    if delay <= 0: _start_pending()
    return true

func _start_pending() -> void:
    current_id = pending_id
    pending_id = ""
    seen[current_id] = true
    play_counts[current_id] = int(play_counts.get(current_id, 0)) + 1
    age = 0.0
    tail_left = -1.0
    subtitle.text = lines[current_id].zh
    subtitle.modulate.a = 0.0
    subtitle.show()
    voice.stream = streams[current_id]
    voice.pitch_scale = 1.0
    voice.play()
    voice.stream_paused = not focused
    game.audio.dialogue_active = true
    game.audio.silence_boss_vocals()

func _voice_finished() -> void:
    # Release the music immediately; keep a short readable subtitle fade.
    game.audio.dialogue_active = false
    tail_left = 0.35
    cooldown = 1.1

func crown_tick(time: float) -> void:
    if time >= 0.55 and time < 8.8 and not seen.has("crown"):
        say("crown")

func end_cinematic(skipped: bool) -> void:
    if skipped or current_id == "crown" or pending_id == "crown": stop()

func on_heavy(profile: Dictionary) -> bool:
    if game.stage != "fight" or game.review_dashboard or terminal_id != "": return false
    if float(profile.get("damage", 0)) < 30 or seen.has("heavy"): return false
    heavy_count += 1
    if heavy_count < heavy_choice: return false
    return say("heavy")

func on_roar() -> bool:
    if game.stage != "fight" or game.review_dashboard: return false
    # Roar is tied to the actual animation entry, not a timer or its damage window.
    return say("roar", true)

func on_result(player_won: bool) -> void:
    var id := "warden_fallen" if player_won else "player_fallen"
    if terminal_id != "": return
    terminal_id = id
    say(id, true, 0.65)

func _process(delta: float) -> void:
    if not focused: return
    cooldown = maxf(0.0, cooldown - delta)
    if pending_id != "":
        pending_delay -= delta
        if pending_delay <= 0: _start_pending()
    if current_id == "": return
    age += delta
    subtitle.modulate.a = clampf(age / 0.14, 0, 1)
    if tail_left >= 0:
        tail_left -= delta
        subtitle.modulate.a = clampf(tail_left / 0.35, 0, 1)
        if tail_left <= 0: stop()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        focused = false
        if voice: voice.stream_paused = true
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        focused = true
        if voice: voice.stream_paused = false

func _exit_tree() -> void:
    if voice: voice.stop()
